(in-package #:cl-user)


(defpackage :cl-data-structures
  (:use #:common-lisp #:iterate #:alexandria
        #:serapeum #:metabang-bind)
  (:nicknames #:cl-ds)
  (:shadowing-import-from #:iterate #:collecting #:summing #:in)
  (:export
   #:*traverse-callback*
   #:across
   #:add
   #:add!
   #:add!-function
   #:add-function
   #:aggregate
   #:apply-layer
   #:argument-out-of-bounds
   #:at
   #:become-functional
   #:become-lazy
   #:become-mutable
   #:become-transactional
   #:clone
   #:consume-back
   #:consume-front
   #:delay
   #:delayed
   #:destructive-counterpart
   #:destructive-function
   #:destructive-function
   #:drop-back
   #:drop-front
   #:empty-clone
   #:empty-container
   #:erase
   #:erase!
   #:erase!-function
   #:erase-function
   #:erase-if
   #:erase-if!
   #:erase-if!-function
   #:erase-if-function
   #:expression
   #:force
   #:found
   #:freeze!
   #:frozenp
   #:full-bucket-p
   #:functional
   #:functional-add-function
   #:functional-counterpart
   #:functional-erase-function
   #:functional-erase-if-function
   #:functional-function
   #:functional-insert-function
   #:functional-put-function
   #:functional-take-out-function
   #:functional-update-function
   #:functionalp
   #:fundamental-assignable-forward-range
   #:fundamental-assignable-range
   #:fundamental-bidirectional-range
   #:fundamental-container
   #:fundamental-forward-range
   #:fundamental-forward-range
   #:fundamental-modification-operation-status
   #:fundamental-random-access-range
   #:fundamental-range
   #:grow-bucket
   #:grow-bucket!
   #:grow-function
   #:hash-content
   #:hash-content-hash
   #:hash-content-location
   #:ice-error
   #:initialization-error
   #:initialization-out-of-bounds
   #:insert
   #:insert!-function
   #:insert-function
   #:invalid-argument
   #:key-value-range
   #:lazy
   #:make-bucket
   #:make-bucket-from-multiple
   #:make-delay
   #:make-from-traversable
   #:make-state
   #:map-bucket
   #:melt!
   #:mod-bind
   #:mutable
   #:mutablep
   #:near
   #:not-implemented
   #:null-bucket
   #:null-bucket-p
   #:operation-not-allowed
   #:out-of-bounds
   #:peek-back
   #:peek-front
   #:position-modification
   #:put
   #:put!
   #:put!-function
   #:put-function
   #:read-arguments
   #:read-bounds
   #:read-class
   #:read-value
   #:reset!
   #:send
   #:shrink-bucket
   #:shrink-bucket!
   #:shrink-function
   #:size
   #:special-traverse
   #:take-out
   #:take-out!
   #:take-out!-function
   #:take-out-function
   #:textual-error
   #:transaction
   #:transactional
   #:transactionalp
   #:traversable
   #:traverse
   #:traverse-through
   #:update
   #:update!
   #:update!-function
   #:update-function
   #:update-if
   #:update-if!
   #:update-if!-function
   #:update-if-function
   #:value
   #:whole-range
   #:xpr))


(defpackage :cl-data-structures.meta
  (:use #:common-lisp #:iterate #:alexandria
        #:serapeum #:metabang-bind)
  (:nicknames #:cl-ds.meta)
  (:shadowing-import-from #:iterate #:collecting #:summing #:in)
  (:export))
