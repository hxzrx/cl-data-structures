(in-package #:cl-data-structures)


(defclass expression (c2mop:funcallable-standard-object
                      traversable)
  ((%construct-function :initarg :construct-function
                        :type (-> () function)
                        :reader read-body)
   (%arguments :initarg :arguments
               :initform nil
               :reader read-arguments))
  (:metaclass c2mop:funcallable-standard-class))


(defmethod initialize-instance :after ((obj expression) &rest all
                                       &key &allow-other-keys)
  (declare (ignore all))
  (bind (((:slots %construct-function %arguments) obj))
    (c2mop:set-funcallable-instance-function obj
                                             (apply %construct-function
                                                    %arguments))))


(defmacro xpr (arguments &body body)
  (let ((keys (plist-keys arguments)))
    (with-gensyms (!fn)
      `(cl-ds.utils:let-generator ((,!fn ,(mapcar (lambda (x) (intern (symbol-name x))) keys)
                                         ,@body))
         (make 'cl-ds:expression
               :construct-function (function ,!fn)
               :arguments (list ,@arguments))))))


(defmethod traverse (function (obj expression))
  (bind (((:slots %construct-function %arguments) obj)
         (fn (apply %construct-function %arguments)))
    (iterate
      (for (values value not-finished) = (funcall fn))
      (while not-finished)
      (funcall function value))
    obj))


(defmethod reset ((obj expression))
  (bind (((:slots %construct-function %arguments) obj))
    (c2mop:set-funcallable-instance-function obj
                                             (apply %construct-function
                                                    %arguments))))
