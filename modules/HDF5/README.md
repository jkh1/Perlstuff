These modules provide an object-oriented interface to the <a href="http://www.hdfgroup.org/HDF5/">HDF5</a> file format. Note the following limitations:
     - requires gcc compiler (due to use of variable lengths arrays in structs)
     - some low-level interfaces are not available (e.g. property list, reference...)
     - supported data types for reading are: integer, float, string, opaque, compound, enum and array.
     - datasets can't have more than 5 dimensions.
     - enum data are read as integers
     - opaque data are read as arrays of uint8 values and written as variable length arrays of uint8 values
     - arrays can only have numeric data types (i.e. integer or float)
     - nested arrays are not supported
     - compound data are limited to the following data types:
           integer, enum, float, string and array.
     - nested compound data are not supported
     - in some instances, memory is allocated on the stack
