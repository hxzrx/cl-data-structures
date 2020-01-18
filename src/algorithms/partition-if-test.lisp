(cl:in-package #:cl-user)
(defpackage partition-if-tests
  (:use :cl :prove :cl-data-structures.aux-package))

(in-package #:partition-if-tests)

(plan 20)

(let ((result (~> #(0 1 2 3 4 5 6 7 8 9 10 11)
                  (cl-ds.alg:partition-if (lambda (prev next)
                                            (eql (truncate prev 3)
                                                 (truncate next 3))))
                  cl-ds.alg:to-vector)))
  (is (cl-ds:at result 0) #(0 1 2) :test #'vector=)
  (is (cl-ds:at result 1) #(3 4 5) :test #'vector=)
  (is (cl-ds:at result 2) #(6 7 8) :test #'vector=)
  (is (cl-ds:at result 3) #(9 10 11) :test #'vector=))

(let ((result (~> #(0 1 2 3 4 5 6 7 8 9 10 11)
                  (cl-ds.alg:partition-if (lambda (prev current)
                                            (< (- current prev) 3))
                                          :on-first t)
                  cl-ds.alg:to-vector)))
  (is (cl-ds:at result 0) #(0 1 2) :test #'vector=)
  (is (cl-ds:at result 1) #(3 4 5) :test #'vector=)
  (is (cl-ds:at result 2) #(6 7 8) :test #'vector=)
  (is (cl-ds:at result 3) #(9 10 11) :test #'vector=))

(let ((result (~> #(0 1 2 3 4 5 6 7 8 9 10 11)
                  (cl-ds.alg:partition-if #'= :key (lambda (x) (truncate x 3)))
                  cl-ds.alg:to-vector)))
  (is (cl-ds:at result 0) #(0 1 2) :test #'vector=)
  (is (cl-ds:at result 1) #(3 4 5) :test #'vector=)
  (is (cl-ds:at result 2) #(6 7 8) :test #'vector=)
  (is (cl-ds:at result 3) #(9 10 11) :test #'vector=))

(bind ((expected-results #(#(0 1 2)
                           #(3 4 5)
                           #(6 7 8)
                           #(9 10 11)))
       (current-index 0)
       ((:flet check (data))
        (is data (aref expected-results current-index)
            :test #'vector=)
        (incf current-index)))
  (~> #(0 1 2 3 4 5 6 7 8 9 10 11)
      (cl-ds.alg:partition-if-with-callback
       #'= #'check :key (lambda (x) (truncate x 3)))
      cl-ds.alg:to-vector))

(bind ((expected-results #(#(0 1 2)
                           #(3 4 5)
                           #(6 7 8)
                           #(9 10 11)))
       (current-index 0)
       ((:flet check (data))
        (is data (aref expected-results current-index)
            :test #'vector=)
        (incf current-index)))
  (~> (cl-ds:xpr (:i 0)
        (when (< i 12) (cl-ds:send-recur i :i (1+ i))))
      (cl-ds.alg:partition-if-with-callback
       (lambda (prev current)
         (< (- current prev) 3))
       #'check
       :on-first t)
      cl-ds.alg:to-vector))

(finalize)
