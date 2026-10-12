The dispatcher is purely combinational.

The `Dispatcher` only advances if:

* [[Reorder Buffer]] is not full 
* [[Issue Queue]] is not full 
* [[Renamer#Output]] output must be valid

Otherwise the pipeline stalls.
