(in-package #:cl-data-structures.dicts.srrb)


(-> insert-tail-handle-root-overflow
    (fixnum
     cl-ds.common.rrb:sparse-rrb-node
     cl-ds.common.rrb:sparse-rrb-node
     t)
    cl-ds.common.rrb:sparse-rrb-node)
(defun insert-tail-handle-root-overflow (shift tree new-node ownership-tag)
  (iterate
    (repeat shift)
    (for node
         initially new-node
         then (cl-ds.common.rrb:make-sparse-rrb-node
               :content (make-array 1 :initial-element node)
               :bitmask 1
               :ownership-tag ownership-tag))
    (finally
     (bind ((content (make-array 2))
            (root (cl-ds.common.rrb:make-sparse-rrb-node
                   :content content
                   :bitmask #b11
                   :ownership-tag ownership-tag)))
       (setf (aref content 0) tree
             (aref content 1) node)
       (return root)))))


(-> make-node-from-tail
    (fundamental-sparse-rrb-vector
     t)
    cl-ds.common.rrb:sparse-rrb-node)
(defun make-node-from-tail (rrb-container ownership-tag)
  (bind (((:slots %tree-size %shift %tree %tail %tail-mask
                  %element-type %tree-index-bound)
          rrb-container)
         (tail-mask %tail-mask)
         (tail-size (logcount tail-mask))
         (tail %tail)
         (element-type (array-element-type tail))
         (new-content
          (if (eql tail-size cl-ds.common.rrb:+maximum-children-count+)
              tail
              (iterate
                (with result = (make-array tail-size :element-type element-type))
                (with j = 0)
                (for i from 0 below cl-ds.common.rrb:+maximum-children-count+)
                (for present = (ldb-test (byte 1 i) tail-mask))
                (when present
                  (setf (aref result j) (aref tail i))
                  (incf j))
                (finally (return result)))))
         (new-node (cl-ds.common.rrb:make-sparse-rrb-node
                    :content new-content
                    :bitmask tail-mask
                    :ownership-tag ownership-tag)))
    new-node))


(defun insert-into-node! (into new-element index)
  (let* ((content (cl-ds.common.rrb:sparse-rrb-node-content into))
         (bitmask (cl-ds.common.rrb:sparse-rrb-node-bitmask into))
         (new-bitmask (dpb 1 (byte 1 index) bitmask))
         (length (length content))
         (position (1- (logcount (ldb (byte (1+ index) 0) new-bitmask))))
         (new-content
           (if (eql length (logcount bitmask))
               (lret ((r (make-array
                          (1+ length)
                          :element-type (array-element-type content))))
                 (setf (cl-ds.common.rrb:sparse-rrb-node-content into) r))
               content)))
    (setf (cl-ds.common.rrb:sparse-rrb-node-bitmask into)
          new-bitmask)
    (iterate
      (for i from 0 below position)
      (setf (aref new-content i) (aref content i)))
    (iterate
      (for i from position below (logcount bitmask))
      (setf (aref new-content (1+ i)) (aref content i)))
    (setf (aref new-content position) new-element)
    new-element))


(-> insert-tail! (mutable-sparse-rrb-vector)
    mutable-sparse-rrb-vector)
(defun insert-tail! (structure)
  (declare (optimize (debug 3)))
  (let ((tail-mask (access-tail-mask structure))
        (ownership-tag nil))
    (unless (zerop tail-mask)
      (bind ((new-node (make-node-from-tail structure ownership-tag))
             ((:accessors (tree access-tree)
                          (tree-size access-tree-size)
                          (%shift access-shift)
                          (tree-index-bound access-tree-index-bound))
              structure)
             (root tree)
             (shift %shift))
        (declare (type non-negative-fixnum shift))
        (cond ((null root)
               (setf tree new-node))
              ((>= (ash tree-index-bound (- cl-ds.common.rrb:+bit-count+))
                   (ash 1 (* cl-ds.common.rrb:+bit-count+ shift))) ; overflow
               (let ((new-root (insert-tail-handle-root-overflow
                                shift root new-node ownership-tag)))
                 (incf %shift)
                 (setf tree new-root)))
              (t (iterate
                   (with size = (access-tree-index-bound structure))
                   (with node = root)
                   (with position = (* cl-ds.common.rrb:+bit-count+ shift))
                   (with p-node = nil)
                   (for index = (ldb (byte cl-ds.common.rrb:+bit-count+
                                           position)
                                     size))
                   (unless (> (decf shift) 0)
                     (finish))
                   (for present = (cl-ds.common.rrb:sparse-rrb-node-contains
                                   node index))
                   (if present
                       (shiftf p-node
                               node
                               (cl-ds.common.rrb:sparse-nref node index))
                       (let* ((new-element
                                (cl-ds.common.rrb:make-sparse-rrb-node
                                 :ownership-tag ownership-tag
                                 :content (make-array 1))))
                         (insert-into-node! node new-element index)
                         (assert (eq (cl-ds.common.rrb:sparse-nref node index)
                                     new-element))
                         (setf node new-element
                               p-node node)))
                   (decf position cl-ds.common.rrb:+bit-count+)
                   (finally
                    (insert-into-node! node new-node
                                       (ldb (byte cl-ds.common.rrb:+bit-count+
                                                  cl-ds.common.rrb:+bit-count+)
                                            size))))))))
    (setf (access-tail-mask structure) 0
          (access-tree-index-bound structure) (access-index-bound structure))
    (when (eql tail-mask (lognot cl-ds.common.rrb:+tail-mask+))
      (setf (access-tail structure) nil))
    (incf (access-index-bound structure)
          cl-ds.common.rrb:+maximum-children-count+)
    (incf (access-tree-size structure) (logcount tail-mask)))
  structure)


(defun insert-tail (structure)
  (declare (optimize (debug 3)))
  (let ((tail-mask (access-tail-mask structure)))
    (if (zerop tail-mask)
        (make (type-of structure)
              :tree (access-tree structure)
              :tail nil
              :tail-mask 0
              :shift (access-shift structure)
              :tree-size (access-tree-size structure)
              :tree-index-bound (access-index-bound structure)
              :index-bound (+ cl-ds.common.rrb:+maximum-children-count+
                              (access-index-bound structure))
              :element-type (read-element-type structure))
        (bind ((new-node (make-node-from-tail structure nil))
               ((:accessors (tree access-tree)
                            (tree-size access-tree-size)
                            (%shift access-shift)
                            (tree-index-bound access-tree-index-bound))
                structure)
               (root tree)
               (shift %shift))
          (declare (type non-negative-fixnum shift))
          (cond ((null root)
                 (setf root new-node))
                ((>= (ash tree-index-bound (- cl-ds.common.rrb:+bit-count+))
                     (ash 1 (* cl-ds.common.rrb:+bit-count+ shift))) ; overflow
                 (let ((new-root (insert-tail-handle-root-overflow
                                  shift root new-node nil)))
                   (incf shift)
                   (setf root new-root)))
                (t (bind ((size (access-tree-index-bound structure))
                          ((:labels impl (node byte-position depth))
                           (if (eql depth 0)
                               new-node
                               (let* ((index (ldb (byte cl-ds.common.rrb:+bit-count+
                                                        byte-position)
                                                  size))
                                      (present (and node (cl-ds.common.rrb:sparse-rrb-node-contains
                                                          node index)))
                                      (next-node (and present (cl-ds.common.rrb:sparse-nref
                                                               node index)))
                                      (current-node (if (null node)
                                                        (cl-ds.common.rrb:make-rrb-node
                                                         :content (make-array 1))
                                                        (cl-ds.common.rrb:deep-copy-sparse-rrb-node
                                                         node (if present 0 1))))
                                      (new-node (impl next-node
                                                      (- byte-position
                                                         cl-ds.common.rrb:+bit-count+)
                                                      (1- depth))))
                                 (setf (cl-ds.common.rrb:sparse-nref current-node index)
                                       new-node)
                                 current-node))))
                     (setf root (impl root
                                      (* cl-ds.common.rrb:+bit-count+ shift)
                                      shift)))))
          (make (type-of structure)
                :tree root
                :tail nil
                :tail-mask 0
                :shift shift
                :tree-size (+ tree-size
                              (logcount (access-tail-mask structure)))
                :tree-index-bound (access-index-bound structure)
                :index-bound (+ cl-ds.common.rrb:+maximum-children-count+
                                (access-index-bound structure))
                :element-type (read-element-type structure))))))


(-> transactional-insert-tail! (transactional-sparse-rrb-vector t)
    transactional-sparse-rrb-vector)
(defun transactional-insert-tail! (structure ownership-tag)
  (declare (optimize (debug 3)))
  (let ((tail-mask (access-tail-mask structure)))
    (unless (zerop tail-mask)
      (bind ((new-node (make-node-from-tail structure ownership-tag))
             ((:accessors (tree access-tree)
                          (tree-size access-tree-size)
                          (%shift access-shift)
                          (tree-index-bound access-tree-index-bound))
              structure)
             (root tree)
             (shift %shift))
        (declare (type non-negative-fixnum shift))
        (cond ((null root)
               (setf tree new-node))
              ((>= (ash tree-index-bound (- cl-ds.common.rrb:+bit-count+))
                   (ash 1 (* cl-ds.common.rrb:+bit-count+ shift))) ; overflow
               (let ((new-root (insert-tail-handle-root-overflow
                                shift root new-node ownership-tag)))
                 (incf %shift)
                 (setf tree new-root)))
              (t (bind ((size (access-tree-index-bound structure))
                        ((:labels impl (node byte-position depth))
                         (if (eql depth 0)
                             new-node
                             (let* ((index (ldb (byte cl-ds.common.rrb:+bit-count+
                                                      byte-position)
                                                size))
                                    (present (and node (cl-ds.common.rrb:sparse-rrb-node-contains
                                                        node index)))
                                    (next-node (and present (cl-ds.common.rrb:sparse-nref
                                                             node index)))
                                    (current-node (or node
                                                      (cl-ds.common.rrb:make-rrb-node
                                                       :content (make-array 1)
                                                       :ownership-tag ownership-tag)))
                                    (owned (cl-ds.common.abstract:acquire-ownership
                                            current-node
                                            ownership-tag))
                                    (new-node (impl next-node
                                                    (- byte-position
                                                       cl-ds.common.rrb:+bit-count+)
                                                    (1- depth))))
                               (if owned
                                   (progn
                                     (setf (cl-ds.common.rrb:sparse-nref current-node index)
                                           new-node)
                                     current-node)
                                   (let ((copy (cl-ds.common.rrb:deep-copy-sparse-rrb-node
                                                current-node (if present 0 1)
                                                ownership-tag)))
                                     (setf (cl-ds.common.rrb:sparse-nref copy index) new-node)
                                     copy)))))
                        (new-tree (impl root
                                        (* cl-ds.common.rrb:+bit-count+ shift)
                                        shift)))
                   (unless (eq new-tree root)
                     (setf tree new-tree)))))))
    (setf (access-tail-mask structure) 0
          (access-tree-index-bound structure) (access-index-bound structure))
    (when (eql tail-mask (lognot cl-ds.common.rrb:+tail-mask+))
      (setf (access-tail structure) nil))
    (incf (access-index-bound structure)
          cl-ds.common.rrb:+maximum-children-count+)
    (incf (access-tree-size structure) (logcount tail-mask)))
  structure)


(-> make-adjusted-tree (fundamental-sparse-rrb-vector fixnum fixnum t)
    cl-ds.common.rrb:sparse-rrb-node)
(defun make-adjusted-tree (structure position new-shift ownership-tag)
  (declare (optimize (debug 3)))
  (bind (((:accessors (root access-tree)
                      (tree-size access-tree-size)
                      (shift access-shift)
                      (tree-index-bound access-tree-index-bound))
          structure)
         (old-shift shift)
         (old-tree-index-bound tree-index-bound)
         (shift-difference (- new-shift old-shift))
         (larger? (> shift-difference 0)))
    (declare (type non-negative-fixnum new-shift
                   new-tree-index-bound
                   old-tree-index-bound
                   old-shift)
             (type boolean larger?)
             (type fixnum shift-difference))
    (assert (not (zerop shift-difference)))
    (if larger?
        (if (null root)
            (cl-ds.common.rrb:make-sparse-rrb-node
             :ownership-tag ownership-tag)
            (iterate
              (with highest-current = (1- old-tree-index-bound))
              (with new-root = (cl-ds.common.rrb:make-sparse-rrb-node
                                :content (make-array 1)
                                :ownership-tag ownership-tag))
              (with node = new-root)
              (with byte-position = (* cl-ds.common.rrb:+bit-count+
                                       new-shift))
              (repeat (1- shift-difference))
              (for i = (ldb (byte cl-ds.common.rrb:+bit-count+ byte-position)
                            highest-current))
              (setf node (insert-new-node! node i ownership-tag))
              (decf byte-position cl-ds.common.rrb:+bit-count+)
              (finally
               (let ((i (ldb (byte cl-ds.common.rrb:+bit-count+
                                   (* (1+ old-shift)
                                      cl-ds.common.rrb:+bit-count+))
                             highest-current)))
                 (cl-ds.common.rrb:with-sparse-rrb-node node
                   (setf (cl-ds.common.rrb:sparse-nref node i) root))
                 (assert (eq (cl-ds.common.rrb:sparse-nref node i)
                             root))
                 (return new-root)))))
        (iterate
          (with node = root)
          (repeat (- shift-difference))
          (setf node (~> node
                         cl-ds.common.rrb:sparse-rrb-node-content
                         first-elt))
          (finally (return node))))))


(deftype shift () `(integer 0 ,cl-ds.common.rrb:+maximal-shift+))
(-> shift-for-position (fixnum) shift)
(defun shift-for-position (position)
  (~> position
      1-
      integer-length
      (/ cl-ds.common.rrb:+bit-count+)
      ceiling
      1-
      (max 0)))


(-> adjust-tree-to-new-size! (fundamental-sparse-rrb-vector fixnum t)
    fundamental-sparse-rrb-vector)
(defun adjust-tree-to-new-size! (structure position ownership-tag)
  (let ((new-shift (shift-for-position position)))
    (unless (eql new-shift (access-shift structure))
      (let ((new-root (make-adjusted-tree structure position new-shift
                                          ownership-tag)))
        (setf (access-shift structure) new-shift
              (access-tree structure) new-root)))
    structure))


(-> set-in-tail! (mutable-sparse-rrb-vector
                  cl-ds.meta:grow-function t
                  cl-ds.common.rrb:rrb-node-position
                  t
                  list)
    (values mutable-sparse-rrb-vector t))
(defun set-in-tail! (structure operation container offset value all)
  (bind (((:accessors (element-type read-element-type)
                      (%tail-mask access-tail-mask)
                      (%tail access-tail))
          structure)
         (tail %tail)
         (tail-mask %tail-mask)
         (present (ldb-test (byte 1 offset) tail-mask)))
    (declare (type (or null cl-ds.common.rrb:node-content) tail)
             (type cl-ds.common.rrb:sparse-rrb-mask tail-mask)
             (type boolean present))
    (if present
        (bind ((old-bucket (aref tail offset))
               ((:values bucket status changed)
                (apply #'cl-ds.meta:grow-bucket! operation
                       container old-bucket value all)))
          (when changed
            (setf (aref tail offset) bucket))
          (values structure status))
        (bind (((:values bucket status changed)
                (apply #'cl-ds.meta:make-bucket
                       operation container
                       value all)))
          (when changed
            (let ((tail-array
                    (or tail
                        (make-array
                         cl-ds.common.rrb:+maximum-children-count+
                         :element-type element-type))))
              (setf (aref tail-array offset) bucket
                    %tail-mask (dpb 1 (byte 1 offset) tail-mask))
              (unless (eq tail tail-array)
                (setf %tail tail-array))))
          (values structure status)))))


(defun tail-copy (tail element-type)
  (if (null tail)
      (make-array
       cl-ds.common.rrb:+maximum-children-count+
       :element-type element-type)
      (copy-array tail)))


(defun set-in-tail (structure operation container offset value all)
  (bind (((:accessors (element-type read-element-type)
                      (%tail-mask access-tail-mask)
                      (%tail access-tail))
          structure)
         (tail %tail)
         (new-tail nil)
         (tail-mask %tail-mask)
         (final-status nil)
         (present (ldb-test (byte 1 offset) tail-mask)))
    (declare (type (or null cl-ds.common.rrb:node-content) tail)
             (type cl-ds.common.rrb:sparse-rrb-mask tail-mask)
             (type boolean present))
    (if present
        (bind ((old-bucket (aref tail offset))
               ((:values bucket status changed)
                (apply #'cl-ds.meta:grow-bucket! operation
                       container old-bucket value all)))
          (when changed
            (setf final-status status
                  new-tail (copy-array tail)
                  (aref new-tail offset) bucket)))
        (bind (((:values bucket status changed)
                (apply #'cl-ds.meta:make-bucket
                       operation container
                       value all)))
          (setf final-status status)
          (when changed
            (setf new-tail (tail-copy tail element-type)
                  (aref new-tail offset) bucket
                  tail-mask (dpb 1 (byte 1 offset) tail-mask)))))
    (values (if (null new-tail)
                structure
                (make (type-of structure)
                      :tree (access-tree structure)
                      :tail new-tail
                      :tail-mask tail-mask
                      :shift (access-shift structure)
                      :tree-size (access-tree-size structure)
                      :tree-index-bound (access-tree-index-bound structure)
                      :element-type (read-element-type structure)
                      :index-bound (access-index-bound structure)))
            final-status)))


(-> insert-new-node! (cl-ds.common.rrb:sparse-rrb-node
                      cl-ds.common.rrb:rrb-node-position
                      &optional t)
    cl-ds.common.rrb:sparse-rrb-node)
(defun insert-new-node! (node i &optional ownership-tag)
  (let* ((old-content (cl-ds.common.rrb:sparse-rrb-node-content node))
         (old-content-size (array-dimension old-content 0))
         (old-bitmask (cl-ds.common.rrb:sparse-rrb-node-bitmask node))
         (new-bitmask (dpb 1 (byte 1 i) old-bitmask))
         (splice-index (1- (logcount (ldb (byte (1+ i) 0) new-bitmask))))
         (old-count (logcount old-bitmask))
         (new-count (1+ old-count))
         (new-content (if (<= new-count old-content-size)
                          old-content
                          (make-array
                           new-count
                           :element-type (array-element-type old-content))))
         (new-node (cl-ds.common.rrb:make-sparse-rrb-node
                    :ownership-tag ownership-tag
                    :content (make-array 1
                                         :element-type (array-element-type
                                                        old-content))
                    :bitmask 0)))
    (unless (eq old-content new-content)
      (setf (cl-ds.common.rrb:sparse-rrb-node-content node) new-content)
      (iterate
        (for i from 0 below splice-index)
        (setf (aref new-content i) (aref old-content i))))
    (iterate
      (for i from splice-index below old-count)
      (setf (aref new-content (1+ i)) (aref old-content i)))
    (setf (aref new-content splice-index)
          new-node
          (cl-ds.common.rrb:sparse-rrb-node-bitmask node) new-bitmask)
    new-node))


(-> transactional-grow-tree! (cl-ds.meta:grow-function
                              transactional-sparse-rrb-vector
                              t
                              fixnum
                              list
                              t)
    (values transactional-sparse-rrb-vector t))
(defun transactional-grow-tree! (operation structure container position all value)
  (bind ((final-status nil)
         (ownership-tag (cl-ds.common.abstract:read-ownership-tag structure))
         (operation-type (type-of operation))
         (size-increased 0)
         (update? (member operation-type
                          '(cl-ds.meta:update!-function
                            cl-ds.meta:update-if!-function)))
         ((:labels impl (node byte-position depth))
          (let* ((i (ldb (byte cl-ds.common.rrb:+bit-count+ byte-position)
                         position))
                 (present (and node (cl-ds.common.rrb:sparse-rrb-node-contains node i))))
            (when (and (not present) update?)
              (return-from transactional-grow-tree!
                (values structure
                        cl-ds.common:empty-eager-modification-operation-status)))
            (if (zerop depth)
                (if present
                    (bind ((current (cl-ds.common.rrb:sparse-nref node i))
                           ((:values new-bucket status changed)
                            (apply #'cl-ds.meta:grow-bucket operation
                                   container current value all)))
                      (if changed
                          (progn
                            (if (cl-ds.common.abstract:acquire-ownership
                                 node ownership-tag)
                                (setf (cl-ds.common.rrb:sparse-nref node i) new-bucket)
                                (setf node (cl-ds.common.rrb:deep-copy-sparse-rrb-node
                                            node 0 ownership-tag)
                                      final-status status
                                      (cl-ds.common.rrb:sparse-nref node i) new-bucket))
                            node)
                          (return-from transactional-grow-tree!
                            (values structure status))))
                    (bind (((:values new-bucket status changed)
                            (apply #'cl-ds.meta:make-bucket
                                   operation container
                                   value all))
                           (node (or node (cl-ds.common.rrb:make-sparse-rrb-node
                                           :content (make-array
                                                     1
                                                     :element-type (read-element-type structure))
                                           :ownership-tag ownership-tag)))
                           (owned (cl-ds.common.abstract:acquire-ownership node ownership-tag)))
                      (if changed
                          (if owned
                              (progn
                                (setf (cl-ds.common.rrb:sparse-nref node i) new-bucket
                                      size-increased 1
                                      final-status status)
                                node)
                              (progn
                                (setf node (cl-ds.common.rrb:deep-copy-sparse-rrb-node
                                            node 1 ownership-tag)
                                      final-status status
                                      (cl-ds.common.rrb:sparse-nref node i) new-bucket)
                                node))
                          (return-from transactional-grow-tree!
                            (values structure status)))))
                (if present
                    (let* ((next-node (cl-ds.common.rrb:sparse-nref node i))
                           (new-node (impl next-node
                                           (- byte-position cl-ds.common.rrb:+bit-count+)
                                           (1- depth))))
                      (if (eq new-node next-node)
                          node
                          (progn
                            (unless (cl-ds.common.abstract:acquire-ownership
                                     node ownership-tag)
                              (setf node (cl-ds.common.rrb:deep-copy-sparse-rrb-node
                                          node 0 ownership-tag)))
                            (setf (cl-ds.common.rrb:sparse-nref node i) new-node)
                            node)))
                    (let ((new-node (impl nil
                                          (- byte-position cl-ds.common.rrb:+bit-count+)
                                          (1- depth)))
                          (current-node (or node (cl-ds.common.rrb:make-sparse-rrb-node
                                                  :content (make-array 1)
                                                  :ownership-tag ownership-tag))))
                      (setf (cl-ds.common.rrb:sparse-nref current-node i) new-node)
                      current-node)))))
         (shift (access-shift structure))
         (tree (access-tree structure))
         (new-tree (impl tree
                         (* cl-ds.common.rrb:+bit-count+ shift)
                         shift)))
    (incf (access-tree-size structure) size-increased)
    (unless (eq tree new-tree)
      (setf (access-tree structure) new-tree))
    (values structure final-status)))


(-> destructive-grow-tree! (cl-ds.meta:grow-function
                            mutable-sparse-rrb-vector
                            t
                            fixnum
                            list
                            t)
    (values mutable-sparse-rrb-vector t))
(defun destructive-grow-tree! (operation structure container position all value)
  (declare (optimize (debug 3)))
  (bind ((final-status nil)
         (operation-type (type-of operation))
         (update? (member operation-type
                          '(cl-ds.meta:update!-function
                            cl-ds.meta:update-if!-function)))
         ((:labels impl (node byte-position depth))
          (let* ((i (ldb (byte cl-ds.common.rrb:+bit-count+ byte-position)
                         position))
                 (present (and node (cl-ds.common.rrb:sparse-rrb-node-contains node i))))
            (when (and (not present) update?)
              (return-from destructive-grow-tree!
                (values structure
                        cl-ds.common:empty-eager-modification-operation-status)))
            (if (zerop depth)
                (if present
                    (bind ((current (cl-ds.common.rrb:sparse-nref node i))
                           ((:values new-bucket status changed)
                            (apply #'cl-ds.meta:grow-bucket! operation
                                   container current value all)))
                      (if changed
                          (progn
                            (setf (cl-ds.common.rrb:sparse-nref node i)
                                  new-bucket
                                  final-status status)
                            node)
                          (return-from destructive-grow-tree!
                            (values structure status))))
                    (bind (((:values new-bucket status changed)
                            (apply #'cl-ds.meta:make-bucket
                                   operation container
                                   value all))
                           (node (or node (cl-ds.common.rrb:make-sparse-rrb-node
                                           :content (make-array
                                                     1
                                                     :element-type (read-element-type structure))))))
                      (if changed
                          (progn
                            (setf (cl-ds.common.rrb:sparse-nref node i) new-bucket
                                  final-status status)
                            (incf (access-tree-size structure))
                            node)
                          (return-from destructive-grow-tree!
                            (values structure status)))))
                (if present
                    (let* ((next-node (cl-ds.common.rrb:sparse-nref node i))
                           (new-node (impl next-node
                                           (- byte-position cl-ds.common.rrb:+bit-count+)
                                           (1- depth))))
                      (unless (eq new-node next-node)
                        (setf (cl-ds.common.rrb:sparse-nref node i) new-node))
                      node)
                    (let ((new-node (impl nil
                                          (- byte-position cl-ds.common.rrb:+bit-count+)
                                          (1- depth)))
                          (current-node (or node (cl-ds.common.rrb:make-sparse-rrb-node
                                                  :content (make-array 1)))))
                      (setf (cl-ds.common.rrb:sparse-nref current-node i) new-node)
                      current-node)))))
         (shift (access-shift structure)))
    (let* ((old-root (access-tree structure))
           (new-root (impl old-root
                           (* cl-ds.common.rrb:+bit-count+ shift)
                           shift)))
      (unless (eq old-root new-root)
        (setf (access-tree structure) new-root)))
    (values structure final-status)))


(defun grow-tree (operation structure container position all value)
  (bind ((final-status nil)
         (ownership-tag nil)
         (operation-type (type-of operation))
         (update? (member operation-type
                          '(cl-ds.meta:update-function
                            cl-ds.meta:update-if-function)))
         (size-increased 0)
         ((:labels impl (node byte-position depth))
          (let* ((i (ldb (byte cl-ds.common.rrb:+bit-count+ byte-position)
                         position))
                 (present (and node (cl-ds.common.rrb:sparse-rrb-node-contains node i))))
            (when (and (not present) update?)
              (return-from grow-tree
                (values structure
                        cl-ds.common:empty-eager-modification-operation-status)))
            (if (zerop depth)
                (if present
                    (bind ((current (cl-ds.common.rrb:sparse-nref node i))
                           ((:values new-bucket status changed)
                            (apply #'cl-ds.meta:grow-bucket operation
                                   container current value all)))
                      (if changed
                          (progn
                            (setf node (cl-ds.common.rrb:deep-copy-sparse-rrb-node
                                        node 0 ownership-tag)
                                  final-status status
                                  (cl-ds.common.rrb:sparse-nref node i) new-bucket)
                            node)
                          (return-from grow-tree
                            (values structure status))))
                    (bind (((:values new-bucket status changed)
                            (apply #'cl-ds.meta:make-bucket
                                   operation container
                                   value all)))
                      (if changed
                          (progn
                            (setf node (if (null node)
                                           (cl-ds.common.rrb:make-sparse-rrb-node
                                            :content (make-array
                                                      1
                                                      :element-type (read-element-type structure))
                                            :ownership-tag ownership-tag)
                                           (cl-ds.common.rrb:deep-copy-sparse-rrb-node
                                            node 1))
                                  (cl-ds.common.rrb:sparse-nref node i) new-bucket
                                  size-increased 1
                                  final-status status)
                            node)
                          (return-from grow-tree
                            (values structure status)))))
                (if present
                    (let* ((next-node (cl-ds.common.rrb:sparse-nref node i))
                           (new-node (impl next-node
                                           (- byte-position cl-ds.common.rrb:+bit-count+)
                                           (1- depth))))
                      (setf node (cl-ds.common.rrb:deep-copy-sparse-rrb-node
                                  node 0 ownership-tag)
                            (cl-ds.common.rrb:sparse-nref node i) new-node)
                      node)
                    (let ((new-node (impl nil
                                          (- byte-position cl-ds.common.rrb:+bit-count+)
                                          (1- depth)))
                          (current-node (if (null node)
                                            (cl-ds.common.rrb:make-sparse-rrb-node
                                             :content (make-array 1))
                                            (cl-ds.common.rrb:deep-copy-sparse-rrb-node
                                             node 1))))
                      (assert current-node)
                      (setf (cl-ds.common.rrb:sparse-nref current-node i) new-node)
                      current-node)))))
         (shift (access-shift structure))
         (tree (access-tree structure))
         (new-tree (impl tree
                         (* cl-ds.common.rrb:+bit-count+ shift)
                         shift))
         (old-tail (access-tail structure))
         (result (make (type-of structure)
                       :tree new-tree
                       :tail (and old-tail (copy-array old-tail))
                       :tail-mask (access-tail-mask structure)
                       :shift (access-shift structure)
                       :tree-size (+ size-increased (access-tree-size structure))
                       :tree-index-bound (access-tree-index-bound structure)
                       :element-type (read-element-type structure)
                       :index-bound (access-index-bound structure))))
    (values result
            final-status)))


(-> destructive-grow-tree! (cl-ds.meta:grow-function
                            mutable-sparse-rrb-vector
                            t
                            fixnum
                            list
                            t)
    (values mutable-sparse-rrb-vector t))
(defun destructive-grow-tree! (operation structure container position all value)
  (declare (optimize (debug 3)))
  (bind ((final-status nil)
         (operation-type (type-of operation))
         (update? (member operation-type
                          '(cl-ds.meta:update!-function
                            cl-ds.meta:update-if!-function)))
         (size-increased 0)
         ((:labels impl (node byte-position depth))
          (let* ((i (ldb (byte cl-ds.common.rrb:+bit-count+ byte-position)
                         position))
                 (present (and node (cl-ds.common.rrb:sparse-rrb-node-contains node i))))
            (when (and (not present) update?)
              (return-from destructive-grow-tree!
                (values structure
                        cl-ds.common:empty-eager-modification-operation-status)))
            (if (zerop depth)
                (if present
                    (bind ((current (cl-ds.common.rrb:sparse-nref node i))
                           ((:values new-bucket status changed)
                            (apply #'cl-ds.meta:grow-bucket! operation
                                   container current value all)))
                      (if changed
                          (progn
                            (setf (cl-ds.common.rrb:sparse-nref node i)
                                  new-bucket
                                  final-status status)
                            node)
                          (return-from destructive-grow-tree!
                            (values structure status))))
                    (bind (((:values new-bucket status changed)
                            (apply #'cl-ds.meta:make-bucket
                                   operation container
                                   value all))
                           (node (or node (cl-ds.common.rrb:make-sparse-rrb-node
                                           :content (make-array
                                                     1
                                                     :element-type (read-element-type structure))))))
                      (if changed
                          (progn
                            (setf (cl-ds.common.rrb:sparse-nref node i) new-bucket
                                  size-increased 1
                                  final-status status)
                            (incf (access-tree-size structure))
                            node)
                          (return-from destructive-grow-tree!
                            (values structure status)))))
                (if present
                    (let* ((next-node (cl-ds.common.rrb:sparse-nref node i))
                           (new-node (impl next-node
                                           (- byte-position cl-ds.common.rrb:+bit-count+)
                                           (1- depth))))
                      (unless (eq new-node next-node)
                        (setf (cl-ds.common.rrb:sparse-nref node i) new-node))
                      node)
                    (let ((new-node (impl nil
                                          (- byte-position cl-ds.common.rrb:+bit-count+)
                                          (1- depth)))
                          (current-node (or node (cl-ds.common.rrb:make-sparse-rrb-node
                                                  :content (make-array 1)))))
                      (setf (cl-ds.common.rrb:sparse-nref current-node i) new-node)
                      current-node)))))
         (shift (access-shift structure)))
    (incf (access-tree-size structure) size-increased)
    (let* ((old-root (access-tree structure))
           (new-root (impl old-root
                           (* cl-ds.common.rrb:+bit-count+ shift)
                           shift)))
      (unless (eq old-root new-root)
        (setf (access-tree structure) new-root)))
    (values structure final-status)))


(defun shrink-tree! (operation structure container position all)
  (declare (optimize (debug 3)))
  (bind ((final-status nil)
         ((:labels impl (node byte-position depth))
          (let ((index (ldb (byte cl-ds.common.rrb:+bit-count+ byte-position)
                            position)))
            (unless (cl-ds.common.rrb:sparse-rrb-node-contains node index)
              (return-from shrink-tree!
                (values structure
                        cl-ds.common:empty-eager-modification-operation-status)))
            (if (zerop depth)
                cl-ds.utils:todo
                (let* ((next-node (cl-ds.common.rrb:sparse-nref node index))
                       (new-node (impl next-node
                                       (- byte-position
                                          cl-ds.common.rrb:+bit-count+)
                                       (1- depth))))
                  (cond ((eq next-node new-node)
                         (return-from shrink-tree!
                           (values structure final-status)))
                        ((null new-node)
                         (unless (eql 1 (cl-ds.common.rrb:sparse-rrb-node-size node))
                           cl-ds.utils:todo))
                        (t (setf (cl-ds.common.rrb:sparse-nref node index)
                                 new-node)
                           node))))))
         (root (access-tree structure))
         (shift (access-shift structure))
         (new-root (impl root
                         (* cl-ds.common.rrb:+bit-count+ shift)
                         shift)))
    (unless (eq new-root root)
      (setf (access-tree structure) new-root))
    (values structure final-status)))


(defun unset-in-tail! (operation structure container offset all)
  (declare (optimize (debug 3)))
  (let* ((tail-mask (access-tail-mask structure))
         (present (ldb-test (byte 1 offset) tail-mask)))
    (if present
        (bind ((tail (access-tail structure))
               (current-bucket (aref tail offset))
               ((:values new-bucket status changed)
                (apply #'cl-ds.meta:shrink-bucket!
                       operation container current-bucket all)))
          (if changed
              (progn
                (setf (access-tail-mask structure)
                      (dpb 0 (byte 1 offset) tail-mask))
                (unless (cl-ds.meta:null-bucket-p new-bucket)
                  (setf (aref tail offset) new-bucket))
                (values structure status))
              (values structure
                      cl-ds.common:empty-eager-modification-operation-status)))
        (values structure
                cl-ds.common:empty-eager-modification-operation-status))))


(defun remove-last-node! (operation structure container position all)
  (declare (optimize (debug 3)))
  cl-ds.utils:todo)