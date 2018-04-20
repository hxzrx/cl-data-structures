(in-package #:cl-user)


(defpackage :cl-data-structures.algorithms.meta
  (:use #:common-lisp #:serapeum #:cl-ds.utils
        #:alexandria #:iterate #:cl-ds #:bind)
  (:shadowing-import-from #:iterate #:collecting #:summing #:in)
  (:nicknames #:cl-ds.alg.meta)
  (:export
   #:aggregate
   #:aggregation-function
   #:aggregation-stage
   #:apply-aggregation-function
   #:apply-layer
   #:apply-range-function
   #:begin-aggregation
   #:construct-aggregator
   #:end-aggregation
   #:extract-result
   #:gather-prior-states
   #:layer-function
   #:linear-aggregator
   #:aggregator-finished-p
   #:make-linear-aggregator
   #:make-state
   #:multi-aggregation-function
   #:multi-aggregation-stages
   #:pass-to-aggregation
   #:range-function
   #:stage
   #:state-result
   #:transformation!-function))


(defpackage :cl-data-structures.algorithms
  (:use #:common-lisp #:serapeum #:cl-ds.utils
        #:alexandria #:iterate #:cl-ds #:bind #:cl-ds.alg.meta)
  (:shadowing-import-from #:iterate #:collecting #:summing #:in)
  (:nicknames #:cl-ds.alg)
  (:export
   #:accumulate
   #:chain
   #:gather-prior-states
   #:group-by
   #:group-by-function
   #:hash-join
   #:make-hash-table-range
   #:on-each
   #:proxy-box-range
   #:proxy-range
   #:summary
   #:summary-function
   #:zip))
