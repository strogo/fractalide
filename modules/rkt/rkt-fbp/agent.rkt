#lang typed/racket/base

; TODO : what to do with unconnected output port? For the moment, the msg is silently destroy

(provide (struct-out agent)
         (struct-out opt-agent)
         recv
         send
         recv-option
         get-in get-out get-in-array get-out-array
         agent-connect agent-connect-to-array agent-connect-array-to
         agent-disconnect agent-disconnect-to-array agent-disconnect-array-to
         agent-no-input?
         make-agent)

(require racket/list)
(require fractalide/modules/rkt/rkt-fbp/port)
(require fractalide/modules/rkt/rkt-fbp/def)

;;
;; Methods for using the agent
;;

(: recv (-> (U (cons Integer port) port) Any))
(define (recv port)
  (if (cons? port)
    (port-recv (cdr port))
    (port-recv port)))

(: try-recv (-> (U (cons Integer port) port) Any))
(define (try-recv port)
  (if (cons? port)
      (port-try-recv (cdr port))
      (port-try-recv port)))

(: send (-> (U False port) Any Void))
(define (send port msg)
  (if port
      (port-send port msg)
      (void)))

;;
;; Methods for building the input arguments of the procedure
;;

(: recv-option (-> agent agent))
(define (recv-option agt)
  (let* ([opt (hash-ref (agent-inport agt) "option")]
         [msg (port-try-recv opt)])
    (if msg
        (recv-option (struct-copy agent agt [option msg]))
        agt)))

(: get-in (-> agent String port))
(define (get-in agent port)
  (hash-ref (agent-inport agent) port))

(: get-out (-> agent String (U False port)))
(define (get-out agent port)
  (hash-ref (agent-outport agent) port))

(: get-in-array (-> agent String in-array-port))
(define (get-in-array agent port)
  (hash-ref (agent-in-array-port agent) port))

(: get-out-array (-> agent String out-array-port))
(define (get-out-array agent port)
  (hash-ref (agent-out-array-port agent) port))



;;
;; Methods for manipulate the agent
;;

; Connect
(: agent-connect (-> agent String port agent))
(define (agent-connect self port sender)
  (let* ([out (agent-outport self)]
        [new-port (hash-set out port sender)])
    (struct-copy agent self [outport new-port])))

; Connect-to-array
; It retrieve the Sender from an input port
(: agent-connect-to-array (-> agent String String String Thread (values port agent)))
(define (agent-connect-to-array self port selection name sched)
  (let* ([in (agent-in-array-port self)]
         [array (hash-ref in port)]
         [selec (hash-ref array selection #f)])
    (if selec
        ; Already existing, add 1 and return
        (let* ([sender (cdr selec)]
               [new-selec (cons (+ (car selec) 1) sender)]
               [new-array (hash-set array selection new-selec)]
               [new-in (hash-set in port new-array)]
               [new-agent (struct-copy agent self [in-array-port new-in])])
          (values sender new-agent))
        ; Not yet existing, set at 1, create and return
        (let* ([sender (make-port 30 name sched #t)]
               [new-selec (cons 1 sender)]
               [new-array (hash-set array selection new-selec)]
               [new-in (hash-set in port new-array)]
               [new-agent (struct-copy agent self [in-array-port new-in])])
          (values sender new-agent)))))

; Connect-array-to
; It set a sender to an array output port
(: agent-connect-array-to (-> agent String String port agent))
(define (agent-connect-array-to self port selection sender)
  (let* ([out (agent-out-array-port self)]
         [array (hash-ref out port)]
         [new-array (hash-set array selection sender)]
         [new-out (hash-set out port new-array)])
    (struct-copy agent self [out-array-port new-out])
    )
  )

; disconnect
(: agent-disconnect (-> agent String agent))
(define (agent-disconnect agt port)
  (let* ([out (agent-outport agt)]
         [new-out (hash-set out port #f)])
    (struct-copy agent agt [outport new-out])))

; disconnect-to-array
(: agent-disconnect-to-array (-> agent String String agent))
(define (agent-disconnect-to-array agt port selection)
  (let* ([in (agent-in-array-port agt)]
         [array (hash-ref in port)]
         [select (hash-ref array selection)]
         [nbr (car select)]
         [sender (cdr select)])
    (if (= nbr 1)
        ; Must remove the selection
        (let* ([new-array (hash-remove array selection)]
               [new-in (hash-set in port new-array)])
          (struct-copy agent agt [in-array-port new-in]))
        ; Must decrease the selection)
        (let* ([new-array (hash-set array selection (cons (- nbr 1) sender))]
               [new-in (hash-set in port new-array)])
          (struct-copy agent agt [in-array-port new-in])))))


; disconnect-array-to
(: agent-disconnect-array-to (-> agent String String agent))
(define (agent-disconnect-array-to agt port selection)
  (let* ([out (agent-out-array-port agt)]
         [array (hash-ref out port)]
         [new-array (hash-remove array selection)]
         [new-out (hash-set out port new-array)])
    (struct-copy agent agt [out-array-port new-out])))

; Are there input port or array input port?
(: agent-no-input? (-> agent Boolean))
(define (agent-no-input? agt)
  (let ([input (agent-inport agt)]
        [input-array (agent-in-array-port agt)])
    (and (= 2 (hash-count input)) (hash-empty? input-array)))) ; 2 because option and acc port

;;
;; Methods for building the agent
;; privates
;;

(: build-inport (-> (Listof String) String Thread (Immutable-HashTable String port)))
(define (build-inport inputs name sched)
  (for/hash: : (Immutable-HashTable String port) ([input inputs])
    (if (or (string=? input "acc") (string=? input "option"))
        ; It's an acc or option port
        (values input (make-port 30 name sched #f))
        ; It's a normal port
        (values input (make-port 30 name sched #t)))))

(: build-outport (-> (Listof String) (Immutable-HashTable String False)))
(define (build-outport outputs)
  (for/hash: : (Immutable-HashTable String False) ([output outputs])
    (values output #f)))

(: build-in-array-port (-> (Listof String) (Immutable-HashTable String in-array-port)))
(define (build-in-array-port inputs)
  (for/hash: : (Immutable-HashTable String in-array-port) ([input inputs])
    (let ([empty : in-array-port (make-immutable-hash)])
      (values input empty))))

(: build-out-array-port (-> (Listof String) (Immutable-HashTable String out-array-port)))
(define (build-out-array-port inputs)
  (for/hash: : (Immutable-HashTable String out-array-port) ([input inputs])
    (let ([empty : out-array-port (make-immutable-hash)])
      (values input empty))))

;;
;; The method to create an agent
;;

(: make-agent (-> opt-agent String Thread agent))
(define (make-agent opt name sched)
  (define agt (agent
   (build-inport (cons "acc" (cons "option" (opt-agent-inport opt))) name sched)
   (build-in-array-port (opt-agent-in-array opt))
   (build-outport (cons "acc" (opt-agent-outport opt)))
   (build-out-array-port (opt-agent-out-array opt))
   (opt-agent-proc opt)
   #f))
  (let* ([input (agent-inport agt)]
        [sender (hash-ref input "acc")])
    (agent-connect agt "acc" sender)))