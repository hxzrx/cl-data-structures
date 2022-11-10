(cl:in-package #:cl-data-structures.algorithms.meta)


(eval-always
  (defun extract-parameters (lambda-list)
    (~>> lambda-list
         (mapcar (lambda (x) (if (listp x) (first x) x)))
         (remove-if (lambda (x) (member x '(&key &optional &rest &allow-other-keys))))))

  (defun key-parameters-start-at (lambda-list)
    (position '&key lambda-list))

  (defun extract-values (lambda-list)
    (bind (((:values required optional rest keys) (parse-ordinary-lambda-list lambda-list)))
      (~> (append required
                  optional
                  (mapcar (lambda (keyform
                                   &aux (keyword (caar keyform)) (name (cadar keyform)))
                            (list keyword name))
                          keys)
                  rest)
          flatten)))

  (defun aggregation-function-class-form (function-class)
    `(defclass ,function-class (cl-ds.alg.meta:aggregation-function)
       ()
       (:metaclass closer-mop:funcallable-standard-class)))

  (defun aggregation-function-defgeneric-form (function-name function-class
                                               generic-lambda-list method-lambda-list
                                               values)
    `(defgeneric ,function-name ,generic-lambda-list
       (:generic-function-class ,function-class)
       (:method ,method-lambda-list
         (apply-range-function range
                               (function ,function-name)
                               (list ,@values)))))

  (defun aggregator-constructor-form (function-class function-state-forms init-body
                                      aggregate-form result-form method-lambda-list
                                      parameters
                                      key-position)
    (let ((function-state (mapcar (lambda (x) (if (atom x) x (first x)))
                                  function-state-forms))
          (function-types (mapcar (lambda (x) (if (atom x) t (second x)))
                                  function-state-forms)))
      (with-gensyms (!after !range !outer-constructor !function !key !arguments !init !main
                              !extract-callback !keys)
        (bind (((aggregate-lambda-list . aggregate-body) aggregate-form))
          `(flet ((,!function (,!key ,!after ,!arguments)
                    (lambda ()
                      (let ,(mapcar (lambda (x) (list x nil)) function-state)
                        (flet ((,!init (,@method-lambda-list)
                                 (declare (ignorable ,@parameters))
                                 ,@init-body)
                               (,!main (,@function-state)
                                 (declare ,@(mapcar (lambda (type symbol) `(type ,type ,symbol))
                                                    function-types
                                                    function-state)
                                          (optimize (speed 3)))
                                 (let ((,!extract-callback (if (or (eq ,!after #'identity)
                                                                 (eq ,!after 'identity)
                                                                 (null ,!after))
                                                             (lambda ()
                                                               ,@result-form)
                                                             (let ((,!after (ensure-function ,!after)))
                                                               (lambda ()
                                                                 (funcall ,!after
                                                                          (progn ,@result-form)))))))
                                   (if (or (eq ,!key #'identity)
                                           (eq ,!key 'identity)
                                           (null ,!key))
                                       (make-aggregator :pass
                                                        (lambda (aggregated-element
                                                            &aux (,@aggregate-lambda-list aggregated-element))
                                                          ,@aggregate-body)
                                                        :extract ,!extract-callback)
                                       (let ((,!key (ensure-function ,!key)))
                                         (make-aggregator :pass
                                                          (lambda (aggregated-element)
                                                            (let ((,@aggregate-lambda-list (funcall ,!key aggregated-element)))
                                                              ,@aggregate-body))
                                                          :extract ,!extract-callback))))))
                          (apply #',!init ,!arguments)
                          (,!main ,@function-state))))))
             (defmethod aggregator-constructor ((,!range cl-ds:traversable)
                                                (,!outer-constructor (eql nil))
                                                (,!function ,function-class)
                                                (,!arguments list))
               (let ((,!keys ,(if key-position
                                  `(drop ,key-position ,!arguments)
                                  nil)))
                 (,!function (getf ,!keys :key)
                             (getf ,!keys :after)
                             ,!arguments)))
             (defmethod aggregator-constructor ((,!range cl:sequence)
                                                (,!outer-constructor (eql nil))
                                                (,!function ,function-class)
                                                (,!arguments list))
               (let ((,!keys ,(if key-position
                                 `(drop ,key-position ,!arguments)
                                 nil)))
                 (,!function (getf ,!keys :key)
                             (getf ,!keys :after)
                             ,!arguments)))))))))


(defmacro define-aggregation-function
    (function-name function-class
     (&rest generic-lambda-list) (&rest method-lambda-list)
     (&rest function-state) init-form
     aggregate-form result-form)
  (assert (find :range generic-lambda-list))
  (assert (find :range method-lambda-list))
  (setf generic-lambda-list (substitute 'range :range generic-lambda-list)
        method-lambda-list (substitute 'range :range method-lambda-list))
  (let ((parameters (extract-parameters generic-lambda-list))
        (key-position (key-parameters-start-at generic-lambda-list))
        (values (extract-values generic-lambda-list)))
    `(progn
       ,(aggregation-function-class-form function-class)
       ,(aggregation-function-defgeneric-form function-name
                                              function-class
                                              generic-lambda-list
                                              method-lambda-list
                                              values)
       ,(aggregator-constructor-form function-class
                                     function-state
                                     init-form
                                     aggregate-form
                                     result-form
                                     method-lambda-list
                                     parameters
                                     key-position))))


(defmacro let-aggregator (bindings
                          ((element) &body pass)
                          (&body extract)
                          &body cleanup)
  `(lambda ()
     (bind ,bindings
       (make-aggregator
        :pass (lambda (,element) ,@pass nil)
        :extract (lambda () ,@extract)
        :cleanup (lambda () ,@cleanup nil)))))
