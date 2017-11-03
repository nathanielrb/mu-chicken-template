(register-feature! 'docker)

(use spiffy slime sparql-query mu-chicken-support)

(load "/app/app.scm")

(vhost-map `((".*" . ,handle-app) ))

(define swank
  (thread-start!
   (make-thread
    (lambda ()
      (swank-server-start (*swank-port*))))))

(format (current-error-port) "~%Starting Spiffy server on port ~A~%" (*port*))

(start-server port: (*port*))

