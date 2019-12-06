(cl:in-package #:cl-data-structures.algorithms)


(cl-ds.alg.meta:define-aggregation-function
    frequency frequency-function
    (:range &key key test)
    (:range &key (key #'identity) (test 'eql))

    (%total-count %sub-counts)

    ((&key test &allow-other-keys)
     (setf %total-count 0
           %sub-counts (make-hash-table :test test)))

    ((element)
     (incf %total-count)
     (incf (gethash element %sub-counts 0) 1))

    ((iterate
       (for (key value) in-hashtable %sub-counts)
       (setf (gethash key %sub-counts)
             (coerce (/ value %total-count) 'single-float))
       (finally (return %sub-counts)))))