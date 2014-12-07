These modules provide an object-oriented interface to the <a href="http://www.hdfgroup.org/HDF5/">HDF5</a> file format.<br> Note the following limitations:
<ul>
     <li>requires gcc compiler (due to use of variable lengths arrays in structs)</li>
     <li>some low-level interfaces are not available (e.g. property list, reference...)</li>
     <li>supported data types for reading are: integer, float, string, opaque, compound, enum and array.</li>
     <li>datasets can't have more than 5 dimensions.</li>
     <li>enum data are read as integers</li>
     <li>opaque data are read as arrays of uint8 values and written as variable length arrays of uint8 values</li>
     <li>arrays can only have numeric data types (i.e. integer or float)</li>
     <li>nested arrays are not supported</li>
     <li>compound data are limited to the following data types:<br>
           integer, enum, float, string and array.</li>
     <li>nested compound data are not supported</li>
     <li>in some instances, memory is allocated on the stack</li>
</ul>
