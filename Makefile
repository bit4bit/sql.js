EMCC=emcc

CFLAGS=-O2 -DSQLITE_OMIT_LOAD_EXTENSION -DSQLITE_DISABLE_LFS -DLONGDOUBLE_TYPE=double -DSQLITE_THREADSAFE=0 -DSQLITE_ENABLE_FTS3 -DSQLITE_ENABLE_FTS3_PARENTHESIS -DSQLITE_OMIT_ALTERTABLE -DSQLITE_OMIT_ANALYZE -DSQLITE_OMIT_ATTACH -DSQLITE_OMIT_AUTHORIZATION -DSQLITE_OMIT_AUTOINCREMENT -DSQLITE_OMIT_BETWEEN_OPTIMIZATION -DSQLITE_OMIT_BLOB_LITERAL -DSQLITE_OMIT_CAST -DSQLITE_OMIT_CHECK -DSQLITE_OMIT_COMPILEOPTION_DIAGS -DSQLITE_OMIT_COMPLETE -DSQLITE_OMIT_COMPOUND_SELECT -DSQLITE_OMIT_DATETIME_FUNCS -DSQLITE_OMIT_DECLTYPE -DSQLITE_OMIT_DEPRECATED -DSQLITE_OMIT_EXPLAIN -DSQLITE_OMIT_FLAG_PRAGMAS -DSQLITE_OMIT_FOREIGN_KEY -DSQLITE_OMIT_GET_TABLE -DSQLITE_OMIT_INCRBLOB -DSQLITE_OMIT_INTEGRITY_CHECK -DSQLITE_OMIT_LIKE_OPTIMIZATION -DSQLITE_OMIT_LOAD_EXTENSION -DSQLITE_OMIT_LOCALTIME -DSQLITE_OMIT_OR_OPTIMIZATION -DSQLITE_OMIT_PAGER_PRAGMAS -DSQLITE_OMIT_PRAGMA -DSQLITE_OMIT_PROGRESS_CALLBACK -DSQLITE_OMIT_REINDEX -DSQLITE_OMIT_SCHEMA_PRAGMAS -DSQLITE_OMIT_SCHEMA_VERSION_PRAGMAS -DSQLITE_OMIT_SHARED_CACHE -DSQLITE_OMIT_SUBQUERY -DSQLITE_OMIT_TEMPDB -DSQLITE_OMIT_TRACE -DSQLITE_OMIT_TRUNCATE_OPTIMIZATION -DSQLITE_OMIT_UTF16 -DSQLITE_OMIT_VACUUM -DSQLITE_OMIT_VIEW -DSQLITE_OMIT_VIRTUALTABLE -DSQLITE_OMIT_XFER_OPT -DSQLITE_UNTESTABLE

all: optimized debug optimized-wasm debug-wasm js/sql.js js/sql-wasm.js

js/sql.js: js/sql-optimized.js
	cp $^ $@

js/sql-wasm.js: js/sql-optimized-wasm.js
	cp $^ $@

# RESERVED_FUNCTION_POINTERS setting is used for registering custom functions
debug-wasm: EMFLAGS= -O1 -g -s INLINING_LIMIT=10 -s RESERVED_FUNCTION_POINTERS=64 -s WASM=1 -s "BINARYEN_METHOD='native-wasm'" -s MODULARIZE=1 -s "EXPORT_NAME='SQL'"
debug-wasm: js/sql-debug-wasm.js

optimized-wasm: EMFLAGS= --memory-init-file 0 --closure 1 -Oz -s INLINING_LIMIT=50 -s RESERVED_FUNCTION_POINTERS=64 -s WASM=1 -s "BINARYEN_METHOD='native-wasm'" -s MODULARIZE=1 -s "EXPORT_NAME='SQL'"
optimized-wasm: js/sql-optimized-wasm.js

optimized: EMFLAGS= --memory-init-file 0 --closure 1 -Oz -s INLINING_LIMIT=50 -s RESERVED_FUNCTION_POINTERS=64 -s MODULARIZE=1 -s "EXPORT_NAME='SQL'"
optimized: js/sql-optimized.js

debug: EMFLAGS= -O1 -g -s INLINING_LIMIT=10 -s RESERVED_FUNCTION_POINTERS=64 -s MODULARIZE=1 -s "EXPORT_NAME='SQL'"
debug: js/sql-debug.js

js/sql%.js: js/sql%-raw.js
	cat $^ > $@

js/sql%-raw.js: c/sqlite3.bc c/extension-functions.bc js/api.js exported_functions
	$(EMCC) $(EMFLAGS) -s EXPORTED_FUNCTIONS=@exported_functions -s EXTRA_EXPORTED_RUNTIME_METHODS=@exported_runtime_methods c/extension-functions.bc c/sqlite3.bc --post-js js/api.js --pre-js js/pre.js -o $@ ;\

js/api.js: coffee/api-data.coffee coffee/api.coffee
	cat $^ | coffee --bare --compile --stdio > $@

c/sqlite3.bc: c/sqlite3.c
	# Generate llvm bitcode
	$(EMCC) $(CFLAGS) c/sqlite3.c -o c/sqlite3.bc

c/extension-functions.bc: c/extension-functions.c
	$(EMCC) $(CFLAGS) -s LINKABLE=1 c/extension-functions.c -o c/extension-functions.bc

module.tar.gz: test package.json AUTHORS README.md js/sql.js
	tar --create --gzip $^ > $@

clean:
	rm -rf js/sql-optimized.js js/sql-debug.js js/sql-optimized-wasm.js js/sql-debug-wasm.js js/sql.js js/sql*-raw.js js/sql-wasm.js js/*.wasm js/*.wast c/sqlite3.bc c/extension-functions.bc
