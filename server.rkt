#lang racket

(require "response.rkt"
         racket/logging
         net/url-string
         json
         threading
         web-server/web-server
         web-server/http/response
         (prefix-in timeout: web-server/dispatchers/dispatch-timeout)
         (prefix-in sequencer: web-server/dispatchers/dispatch-sequencer))
(require web-server/managers/none)

(define (merge a b)
  (cond
    [(empty? a) b]
    [(empty? b) a]
    [else (let ((fa (car a))
                (fb (car b)))
            (if (< fa fb)
                (cons fa (merge (cdr a) b))
                (cons fb (merge a (cdr b)))))]))

(define (get-numbers url)
  (define main-thread (current-thread))
  (thread
   (λ ()
     (with-handlers ([exn:fail? (λ (exn) '())])
       (define nums (~> url
                           bytes->string/utf-8
                           string->url
                           get-pure-port
                           read-json
                           (hash-ref 'numbers)
                           (sort <)))
       (thread-send main-thread '(1 2 3 4 5 6 7))))))

(define (process-numbers req)
  (define start-time (current-inexact-milliseconds))
  (define alarm (alarm-evt (+ (current-inexact-milliseconds) 400)))

  (define numberget-cust (make-custodian))
  (define urls (map binding:form-value (bindings-assq-all #"u" (request-bindings/raw req))))
  (define threads (parameterize ([current-custodian numberget-cust]) (map get-numbers urls)))

  (define nums
    (let loop ([nums '()] [n 1])
      (sync
       (handle-evt (thread-receive-evt)
                   (λ (val)
                     (let* ((result (thread-receive))
                            (new-nums (if result (remove-duplicates (merge nums result)) nums)))
                       (if (= n (length urls))
                           new-nums
                           (loop new-nums (add1 n))))))
       (handle-evt alarm
                   (λ (val)
                     nums)))))
  (collect-garbage 'incremental)
  (response #:code 200 #:body (jsexpr->string (hash 'numbers nums))))

(define-values (go _)
  (dispatch-rules
   [("numbers") #:method "get" process-numbers]
   [else not-found]))

(module+ main
  (println "Listening on port 3000")
  (serve
   #:dispatch (λ (conn req)
                (define resp (go req))
                (output-response/method
                 conn
                 resp
                 (request-method req)))
   #:port 3000
   #:initial-connection-timeout 120)
  (do-not-return))
