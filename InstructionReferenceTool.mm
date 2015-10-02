#import <Foundation/Foundation.h>
#import <Hopper/Hopper.h>
#import <sqlite3.h>

static NSString *const kErrorDomain = @"InstructionReferenceToolErrorDomain";
static NSInteger const kErrorCode = 1000;

@interface InstructionReferenceTool : NSObject<HopperTool>

@end

@implementation InstructionReferenceTool {
    NSObject<HPHopperServices> *_services;
}

#pragma mark - HopperPlugin

- (instancetype)initWithHopperServices:(NSObject <HPHopperServices> *)services {
    self = [super init];
    if (self) {
        _services = (NSObject <HPHopperServices> *)services;
    }
    return self;
}

- (HopperUUID *)pluginUUID {
    return [_services UUIDWithString:@"6BB4CDE9-E2A4-4452-B48E-165A289B5D99"];
}

- (HopperPluginType)pluginType {
    return Plugin_Tool;
}

- (NSString *)pluginName {
    return @"InstructionReference";
}

- (NSString *)pluginDescription {
    return @"Instruction Reference Tool";
}

- (NSString *)pluginAuthor {
    return @"Ievgen Solodovnykov";
}

- (NSString *)pluginCopyright {
    return @"©2015 – Ievgen Solodovnykov";
}

- (NSString *)pluginVersion {
    return @"1.0.0";
}

#pragma mark - HopperTool

- (NSArray *)toolMenuDescription {
    return
    @[@{
          HPM_TITLE: @"Show Current Instruction Reference",
          HPM_SELECTOR: @"showCurrentInstructionReference"
    }];
}

#pragma mark - InstructionReferenceTool

- (BOOL)getMnemonic:(NSString **)mnemonic atAddress:(Address)address {
    NSObject<HPDocument> *document = [_services currentDocument];
    NSObject<HPDisassembledFile> *disassembledFile = [document disassembledFile];
    if (![disassembledFile hasCodeAt:address]) {
        return NO;
    }

    NSObject<CPUContext> *cpuContext = [disassembledFile buildCPUContext];

    DisasmStruct disasm;
    disasm.virtualAddr = address;

    NSObject<HPSegment> *segment = [document currentSegment];
    const uint8_t *bytes = (const uint8_t *)[[segment mappedData] bytes];

    disasm.bytes = bytes + address - [segment startAddress];

    uint8_t cpuMode = [disassembledFile cpuModeAtVirtualAddress:address];
    [cpuContext disassembleSingleInstruction:&disasm usingProcessorMode:cpuMode];

    if (mnemonic != NULL) {
        *mnemonic = [NSString stringWithCString:disasm.instruction.mnemonic encoding:NSASCIIStringEncoding];
    }

    return YES;
}

- (NSString *)fixedIntelMnemonic:(NSString *)mnemonic {
    if ([mnemonic hasPrefix:@"J"] && ![mnemonic isEqualToString:@"JMP"]) {
        return @"Jcc";
    }
    else if ([mnemonic hasPrefix:@"LOOP"]) {
        return @"LOOP";
    }
    else if ([mnemonic hasPrefix:@"INT"]) {
        return @"INT n";
    }
    else if ([mnemonic hasPrefix:@"FCMOV"]) {
        return @"FCMOVcc";
    }
    else if ([mnemonic hasPrefix:@"CMOV"]) {
        return @"CMOVcc";
    }
    else if ([mnemonic hasPrefix:@"SET"]) {
        return @"SETcc";
    }
    return mnemonic;
}

- (NSString *)fixedARMMnemonic:(NSString *)mnemonic {
    return mnemonic;
}

- (NSString *)patchedMnemonic:(NSString *)mnemonic cpuFamily:(NSString *)cpuFamily {
    NSString *result = mnemonic.uppercaseString;
    if ([cpuFamily isEqualToString:@"intel"]) {
        return [self fixedIntelMnemonic:result];
    }
    if ([cpuFamily isEqualToString:@"arm"]) {
        return [self fixedARMMnemonic:result];
    }
    return result;
}

- (NSString *)getMnemonicReference:(NSString *)mnemonic error:(NSError **)error {
    NSObject<HPDocument> *document = [_services currentDocument];
    NSObject<HPDisassembledFile> *disassembledFile = [document disassembledFile];

    NSString *reference = nil;
    NSString *message = nil;
    sqlite3 *connection = NULL;
    sqlite3_stmt *statement = NULL;

    do {
        const char *query = "SELECT description FROM instructions WHERE mnem == ? LIMIT 1";

        NSString *dbPath = [[NSBundle bundleForClass:[self class]] pathForResource:disassembledFile.cpuFamily ofType:@"db"];
        if (dbPath == nil) {
            message = [NSString stringWithFormat:@"Could not load reference database for %@ CPU family, path does not exist", disassembledFile.cpuFamily];
            break;
        }

        if (sqlite3_open([dbPath UTF8String], &connection) != SQLITE_OK) {
            message = [NSString stringWithFormat:@"Could not open reference database for %@ CPU family: \n\t%@", disassembledFile.cpuFamily, dbPath];
            break;
        }

        if (sqlite3_prepare_v2(connection, query, -1, &statement, NULL) != SQLITE_OK) {
            message = @"Error preparing SQL";
            break;
        }

        NSString *patchedMnemonic = [self patchedMnemonic:mnemonic cpuFamily:disassembledFile.cpuFamily];

        if (sqlite3_bind_text(statement, 1, [patchedMnemonic cStringUsingEncoding:NSASCIIStringEncoding], [patchedMnemonic length], NULL) != SQLITE_OK) {
            message = @"Error binding SQL parameters";
            break;
        }

        int result = sqlite3_step(statement);

        if (result == SQLITE_DONE) {
            message = [NSString stringWithFormat:@"Could not find reference for %@", mnemonic];
            break;
        }

        if (result != SQLITE_ROW) {
            message = @"Error executing SQL";
            break;
        }

        const char *referenceText = (const char *)sqlite3_column_text(statement, 0);
        reference = [NSString stringWithCString:referenceText encoding:NSUTF8StringEncoding];
    } while (false);

    if (statement != NULL) {
        sqlite3_finalize(statement);
    }
    if (connection != NULL) {
        sqlite3_close(connection);
    }

    if (message != nil && error != NULL) {
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: message };
        *error = [NSError errorWithDomain:kErrorDomain code:kErrorCode userInfo:userInfo];
    }

    //cross-reference
    if ([reference hasPrefix:@"-R:"]) {
        NSString *newMnemonic = [reference substringFromIndex:3];
        return [self getMnemonicReference:newMnemonic error:error];
    }

    return reference;
}

- (void)logMnemonicReference:(NSString *)mnemonic {
    NSObject<HPDocument> *document = [_services currentDocument];

    NSError *error;
    NSString *reference = [self getMnemonicReference:mnemonic error:&error];

    if (reference != nil) {
        [document logStringMessage:@"\n\n--------------------------------------------------------------------------------------------------------------\n\n"];
        [document logStringMessage:[NSString stringWithFormat:@"Documentation for %@", mnemonic.uppercaseString]];
        [document logStringMessage:@"\n\n--------------------------------------------------------------------------------------------------------------\n\n"];
        [document logStringMessage:reference];
    }
    else if (error != nil) {
        [document logErrorStringMessage:error.localizedDescription];
    }
}

- (void)showCurrentInstructionReference {
    NSObject<HPDocument> *document = [_services currentDocument];
    Address address = [document currentAddress];

    NSString *mnemonic;
    if ([self getMnemonic:&mnemonic atAddress:address]) {
        [self logMnemonicReference:mnemonic];
    }
}

@end
