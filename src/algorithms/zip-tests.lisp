(in-package #:cl-user)
(defpackage zip-tests
  (:use #:cl #:prove #:serapeum #:cl-ds #:iterate #:alexandria)
  (:shadowing-import-from #:iterate #:collecting #:summing #:in))

(in-package #:zip-tests)

(plan 6)

(let* ((vector1 (vect 1 2 3 4 5 6 7))
       (vector2 (vect 8 9 10 11 12))
       (range (cl-ds.alg:zip
               #'list*
               (cl-ds:whole-range vector1)
               (cl-ds:whole-range vector2))))
  (is (cl-ds:size range) (min (length vector1) (length vector2)))
  (iterate
    (for (values value more) = (cl-ds:consume-front range))
    (while more)
    (for v1 in-vector vector1)
    (for v2 in-vector vector2)
    (is value (list* v1 v2) :test #'equal)))

(finalize)
