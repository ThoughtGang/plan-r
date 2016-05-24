# Wing Attack Plan R
Plan R : research and document management system

The core Plan R project is a set of command-line utilities. See 
[plan-r-http](https://github.com/ThoughtGang/plan-r-http) for a
GUI implemented as a local webapp.


## Features
 - context-specific document indexing and clustering
 - document tagging
 - document metadata
 - mirroring of local and remote documents
 - automatic update and re-indexing of mirrored documents
 - optional non-mirrored ("linked") indexing of local and remote documents
 - nested documents
 - integration with R and Octave (not implemented)
 - currently supports plaintext, HTML, PDF, RTF documents


## Applications
 - Up-to-date and indexed mirrors of online resources
 - Associate test data, diagrams, academic papers to source code                
 - Perform statistics on data


## Content Repository

Plan-R is not based around a single. central document repository. Instead,
repositories are assumed to be created on a per-project basis: to group
related documents, to collect related research material, etc. Separate
repositories are distinct and do not interact. Each repository has its own
indexing, version control, filesystem hierarchy, and configuration. Note that
each repository can override the global and user Plan-R config files, for 
example to load plugins (stored within the repository root) which are not
available to other repositories.

The "repository" is known as the Content Repository, and has the following
directory structure:
```
content/
indexes/
metadata/
repo.properties.json
settings/repo.yaml
var/
```
The 'content' and 'metadata' directories form the actual content of the
repository. The 'indexes' directory is used by search engine plugins to
store indexes of repository contents. The 'var' directory is used by various
plugins for runtime (generally, temporary) data.


## Content nodes
The Content Repository supports the following content node types:

  - Document : Any file type. Note that the file format must be supported by a plugin in order for Plan-R to be able to index or display its contents
  - Note : A plaintext (ASCII) file
  - Dict : A JSON-serialized Hash of arbitrary user-supplied data
  - Table : Tabular data, such as Spreadseet contents or a Matrix
  - Script : A script which can be executed by a plugin
  - Query : A "stored query" to be sent to a search-engine plugin

Note that Document is considered the primary type of content in the repo. All
other content types (Note, Dict, Table, Script, Query) can be "attached" to
a Document: that is, they can be given the same name (path) as the document, so
that a UI can choose to display them as metadata for the Document. In addition, 
any content node can be a child of a Document; it is even possible for a 
Document to be the child of another Document. In these cases, the UI will 
present the content nodes in a tree structure, as if the parent document were 
a Folder.

All content nodes have an "origin" property, which may be empty. When a document
is refreshed, its contents are read from the origin and re-indexed. Note that a
document can be refreshed manually, automatically on loading of the UI, or every
time it is accessed. The origin can be a URI, a Query content node, or a Script
content node. This allows for "dynamic documents" whose contents always contain
the latest output of a script, query, or web page.


## Adding a Document
Internally, the process of adding a Document is as follows:

  1. Obtain the document contents using a data_source plugin, determined by the origin or by the application
  2. Run ident plugins on the document to determine its mime-type
  3. Obtain the document resources (e.g. images and javascript required by an HTML file) using a mirror_doc plugin
  4. Localize the document using a rebase_doc plugin, so that all document resources point to the mirrored local version
  5. Run a parse_doc plugin on the document to extract its content in plaintext for analysis
  6. Run all analysis plugins on the document to generate metadata
  7. Tokenize the parsed document, using metadata to make decisions such as stemmer selection
  8. Add the document to the search engine by invoking all index_doc plugins


## Services

Plan R provides the following Application services to the CLI or UI:
 - RepoManager : wrapper for the Content Repository
 - DocumentManager : interface to document-handling plugins
 - QueryManager : interface to search index plugins
 - ScriptManager : Interface to interpreter plugins
 - ConfigManager : Interface to system, user, and per-repository configuration
 - PluginManager : The plugin system
 - JRuby : A JRuby process that provides access to Java classes
 - RevisionControl : Acess to Git for version control of a repository


## Plugin Architecture

Plan R uses the [tg-plugins](https://github.com/ThoughtGang/tg-plugins) module
for its plugin system. Plugins are responsible for all parts of the system that
are considered to be extensible: search engine implementation, file format
support, import/export support, content retrieval, content parsing, and
general content transformation.

The following Plugin interfaces are defined:


  - data_source : Reads the contents of a Document from an origin (repo path, filesystem path, URI, etc). The plugin is responsible for obtaining the contents from the provided origin (path). 
  - mirror_doc : Make a local mirror of a document by fetching all resources and rewriting (localizing) document references to those resources. Requires a data_source plugin to obtain the resources, and generally makes use of a rebase_doc plugin to do the rewriting.
  - parse_doc : Generates a ParsedDocument from a Document. This just extracts the document contents in a usable (plaintext) form.
  - unpack_doc : Used to build compound documents by creating child content nodes under the original document
  - rebase_doc : Repairs links to resources in a document when document has been moved
  - analyze_doc : Perform arbitrary analysis on a document. Examples that ship with Plan-R include summarizing a document, and identifying the language of a document. Note that analysis results generally end up in the Document properties Hash.
  - tokenize_doc : Tokenize an analyzed document
  - index_doc : Add a tokenized Document to the search engine index
  - query_index : Perform a search on an index
  - related_docs : Return a list of documents in the repository that are similar (by a plugin-defined distance metric) to the provided Document. The simlest example is the TagIndex plugin, which will return documents that have the same tags.
  - ident : Identify the type of a file or a string of bytes
  - transform_doc : Create a new Document by transforming a Document. Examples might be to_upper, Kennify, summarize, and so forth. The new Document file format does not have t be the same as the original.
  - export_contents : Export specified paths in the repository to file or directory. The destination can be an archive, database, etc.
  - import_contents : Import content to the repository from a file or directory
  - evaluate : Execute a provided script with a ruby Object (usually a Document) as its argument
  - interpreter : Launch a long-running interpreter in a separate process. This is useful for wrapping programs like Octave or MathKernel.


# Example
First, create a repository:
```
REPO='~/bytecode_analysis.planr'
plan-r-repo-create -d 'Documents and webpages pertaining to analysis of bytecode' -n 'Bytecode Analysis Docs' "$REPO"
```

Create a top-level document 'README':
```
echo "Demonstration Document Repo for Wing Attack Plan R." | plan-r-add-document -1 "$REPO" /README
```

Import a webpage in the folder 'discussion':
```
DOC="/discussion/Binary_Analysis_Isnt.html"
URL='http://web.archive.org/web/20130227035525/http://www.mimisbrunnr.net/~munin/blog/binary-analysis-isnt.html'
plan-r-import-document -1 -O -d "$DOC" "$REPO" "$URL"
plan-r-tag -1 -n 'binary analysis' -t document "$REPO" "$DOC"
plan-r-set-property -1 -t document -p title="Binary Analysis Isn't" "$REPO" "$DOC"
plan-r-add-note -1 "$REPO" "$DOC" 'Site disappeared as of 2015-10-15'
```

Add reference material to the folder 'reference':
```
DOC='/reference/bytecode/LLVM_Bytecode_Format.html'
URL='http://llvm.org/releases/1.3/docs/BytecodeFormat.html'
plan-r-import-document -1 -d "$DOC" "$REPO" "$URL"
plan-r-tag -1 -n 'llvm' -n 'IR' -n 'bytecode' -t document "$REPO" "$DOC"
plan-r-set-property -1 -t document -p title='LLVM Bytecode Format (1.3)' -p version='1.3' "$REPO" "$DOC"

DOC='/reference/bytecode/Dalvik_Bytecode.html'
URL='http://source.android.com/devices/tech/dalvik/dalvik-bytecode.html'
plan-r-import-document -1 -d "$DOC" "$REPO" "$URL"
plan-r-tag -1 -n 'dalvik' -n 'java' -n 'android' -n 'bytecode' -t document "$REPO" "$DOC"
plan-r-set-property -1 -t document -p title='Dalvik Bytecode' "$REPO" "$DOC"

DOC="/reference/bytecode/The_Working_Developers_Guide_to_Java_Bytecode.html"    
URL='http://www.theserverside.com/news/1363881/The-Working-Developers-Guide-to-Java-Bytecode'
plan-r-import-document -1 -d "$DOC" "$REPO" "$URL"
plan-r-tag -1 -n 'java' -n 'bytecode' -t document "$REPO" "$DOC"
plan-r-set-property -1 -t document -p title="The Working Developer's Guide to Java Bytecode" "$REPO" "$DOC"
```

Display the contents of the README file
```
plan-r-cat binalysis.planr /README
```

Recursively list the contents of the 'reference' folder:
```
plan-r-ls -lr binalysis.planr /reference
```

List tags and properties of the LLVM_Bytecode_Format.html document:
```
plan-r-tag binalysis.planr /reference/bytecode/LLVM_Bytecode_Format.html
plan-r-properties binalysis.planr /reference/bytecode/LLVM_Bytecode_Format.html
```

Identify file format of Dalvik_Bytecode.html:
```
plan-r-ident binalysis.planr /reference/bytecode/Dalvik_Bytecode.html
```

Search all documents for occurrences of the word "virtual":
```
plan-r-query binalysis.planr virtual
```

List documents related to "Dalvik_Bytecode.html":
```
plan-r-related-documents binalysis.planr /reference/bytecode/Dalvik_Bytecode.html
```


# Commands

Plan-R provides the following command-line utilities:

  - plan-r-add-content
  - plan-r-add-dict
  - plan-r-add-document
  - plan-r-add-note
  - plan-r-add-query
  - plan-r-add-script
  - plan-r-add-table
  - plan-r-analyze
  - plan-r-cat
  - plan-r-cp
  - plan-r-dump-config
  - plan-r-export
  - plan-r-find-file
  - plan-r-ident
  - plan-r-import
  - plan-r-import-document
  - plan-r-inspect
  - plan-r-jruby-service
  - plan-r-ls
  - plan-r-mkdir
  - plan-r-mv
  - plan-r-open
  - plan-r-parse
  - plan-r-path
  - plan-r-plugin-info
  - plan-r-plugin-list
  - plan-r-properties
  - plan-r-query
  - plan-r-reindex
  - plan-r-related-documents
  - plan-r-repo-create
  - plan-r-rm
  - plan-r-set-property
  - plan-r-tag
  - plan-r-tokenize
  - plan-r-transform
  - plan-r-update
  - plan-r-vc


# License
https://github.com/mkfs/pogo-license
This is the standard BSD 3-clause license with a 4th clause added to prohibit 
non-collaborative communication with project developers. 
