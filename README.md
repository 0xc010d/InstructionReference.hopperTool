InstructionReference.hopperTool
======
Hopper Instruction Reference Tool Plugin.

Shamelessly ported from the excellent [HopperRef plugin by zbuc](https://github.com/zbuc/hopperref).

Installation
------------
Simply checkout or download the repository and use cmake/make to install it.
Please also note that you need Xcode's developer tools and sqlite3 to be available.

    git clone https://github.com/0xc010d/InstructionReference.hopperTool.git
    cd InstructionReference.hopperTool
    git submodule init && git submodule update
    mkdir build && cd build
    cmake .. && make install

Restart Hopper Disassembler and you should see a "Show Current Instruction Reference" option in the "Tool Plugins" menu item.

*Now for plagiarized documentation from nologic because he did all the hard work*

Internals
---------
Upon loading the script will look for SQlite databases in the same directory as the 
itself. The naming convention for the database files is [arch name].sql. The 
[arch name] will be presented to the user as choice.

The database has a table called 'instructions' and two columns called 'mnem' and
'description'. The instructions are looked up case insensitive (upper case) by the
mnem value. The text from description is displayed verbatim in the view.

To add support for more architectures simply create a new database with those
columns and place it in the the script directory.

    import sqlite3 as sq
    con = sq.connect("asm.sqlite")
    con.text_factory = str
    cur = con.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS instructions (platform TEXT, mnem TEXT, description TEXT)")
    con.commit()
    
When working with x86, I noticed that many instructions point to the same documentation.
So, the plugin supports level referencing. Just place '-R:[new instruction]' into
description to redirect the loading. 'new instruction' is the target. So, when loading 
the script will detect the link and load the new target automatically.

    cur.execute("INSERT INTO instructions VALUES (?, ?, ?)", ("x86", inst, "-R:%s" % first_inst))
    
Skeletons in the closet
-----------------------
The documentation database was created using a rather hackish screen scraping
technique by the x86doc project which I forked. So, there are probably some 
strange characters or tags in the text. At least, it is a mechanical process
so I expect that the information is correct relative to the original Intel PDF.

Enjoy!
------
