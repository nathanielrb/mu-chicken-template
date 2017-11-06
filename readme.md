# Chicken Scheme Template

Template for running [Chicken Scheme](http://wiki.call-cc.org/man/4/The%20User%27s%20Manual) microservices.

## Configuration

The template supports the following environment variables, from the modules `mu-chicken-support` and `sparql-query`:

- `MU_SPARQL_ENDPOINT`: SPARQL read endpoint URL. Default: http://database:8890/sparql in Docker, and http://localhost:8890/sparql outside Docker. Can be accessed and overridden using the dynamic parameter `(*sparql-endpoint*)`.
- `MU_SPARQL_UPDATE_ENDPOINT`: SPARQL update endpoint. Same defaults as preceding. Can be accessed and overridden using the dynamic parameter `(*sparql-update-endpoint*)`.
- `MU_APPLICATION_GRAPH`: configuration of the graph in the triple store the microservice will work in. The graph name can be accessed via the `(*default-graph*)` dynamic parameter. Defaults to `'<http://mu.semte.ch/application>`. 
- `PORT`: the port to run the application on, defaults to 80.
- `SWANK_PORT`: port for running the swank server, defaults to 4005.
- `MESSAGE_LOGGING`: turns logging on or off.
- `PRINT_SPARQL_QUERIES`: when "true", print all SPARQL queries.

## Usage

Put your application in a file "app.scm", and define REST endpoints with `define-rest-call` as described below:

```
(define sync-call
  (rest-call
    (realm-id)
      (sparql-update 
        (conc "DELETE { "
              "  GRAPH <http://example.com/application> { "
              "    ?s ?p ?o "
              "  } "
              "} "
              "INSERT { ?s ?p ?newo } "
              "WHERE { "
              "  ?s a ~A. "
              "  BIND(IF(DATATYPE(?o)=<http://www.w3.org/2001/XMLSchema#string>, STR(?o), ?o) AS ?newo) "
              "}")
        'skos:Concept)
    '((success . "ok"))))

(define-rest-call 'POST '("sync" realm-id) sync-call)
```

Add a Dockerfile:

```
FROM semtech/mu-chicken-template
MAINTAINER Nathaniel Rudavsky-Brody <nathaniel.rudavsky@gmail.com>
```

Any Chicken modules ("eggs") listed in requirements.txt will be installed with `chicken-install`. (This file is optional but should not be empty.)

Finally, add this to your docker-compose.yml:

```
version: "2"
services:
  myapp:
    build: ./myapp
    ports:
      - "4028:80"
      - "4005:4005"
    environment:
      MU_DEFAULT_GRAPH: "http://example.com/application"
```

### Swank

In the docker-compose file above, port 4005 connects to the Swank server.

You can use the Chicken `slime` module ([github](https://github.com/nickg/swank-chicken) and [chicken](http://wiki.call-cc.org/eggref/4/slime)) to establish a client connection from Emacs, but it takes some tweaking to use only the client side of this module. A simpler solution is just to do `M-x slime-connect` and ignore error messages about incompatible types between Lisp and Scheme.

## Helper Functions

### Chicken Modules

The template makes available by default the following Chicken modules:

- [spiffy](http://wiki.call-cc.org/eggref/4/spiffy): web server library, used for defining the REST handlers described below below. See also [spiffy-request-vars](https://wiki.call-cc.org/eggref/4/spiffy-request-vars) for accessing request paramaters, and [http-client](http://wiki.call-cc.org/eggref/4/http-client) and [intarweb](http://wiki.call-cc.org/eggref/4/intarweb) for lower-level control over http requests.
- [medea](http://wiki.call-cc.org/eggref/4/medea): JSON parsing and writing. When performance is important, the faster [cjson](http://wiki.call-cc.org/eggref/4/cjson) is also used for parsing large JSON objects.
- [matchable](http://wiki.call-cc.org/eggref/4/matchable): pattern matching

The experimental module [s-sparql](https://github.com/nathanielrb/s-sparql) for parsing and transforming SPARQL queries is available but not loaded by default.

### Helpers

Test if we're inside Docker:

```
(feature? 'docker)
```

Generate a uuid:

```
(generate-uuid)
;; => "5509b40b-0e0e-468e-b87a-2768b51e24ea"
```

Message logging, using format strings:

```
(log-message "Error: ~A~%" error-msg)
```

There are also utility functions for creating JSON-API and JSON-LD objects.

### Defining REST calls

REST calls are functions of one parameter (an alist representing path variable bindings) and must return a Scheme representation of a JSON object parseable by [medea](http://wiki.call-cc.org/eggref/4/medea). They can be defined directly, or using the `rest-call` macro, and are registered with `define-rest-call`:

```
(define (name-call bindings)
  `((message . ,(conc "Hello, " (alist-ref 'name bindings)))))

(define-rest-call 'GET '("person" name) name-call)

(define bye-call
  (rest-call (name)
    `((message . ,(conc "Goodbye, " name)))))

(define-rest-call 'DELETE ('"person" name) bye-call)
```

Use the `mu-headers` dynamic parameter to send custom headers:

```
(define bye
 (rest-call (name)
     (mu-headers '((custom-header "header value")))
     `((message . ,(conc "Goodbye, " name))))))
```

The request body can be parsed as a string or JSON object using `read-request-body` and `read-request-json`, and headers accessed using `header`. Request parameters can be accessed using procedures defined by the [spiffy-request-vars](https://wiki.call-cc.org/eggref/4/spiffy-request-vars) module. Custom error messages can be sent in JSON-API format using the function `send-error`:

```
(use spiffy-request-vars)

(define-rest-call 'PATCH '("person" id)
  (rest-call (id)
    (let (($query (request-vars source: 'query-string))
          (body (read-request-json)))     ; => '((data . ((type . "person") (attributes . ((name . "John Edwards") ...)))))
      (if (or (equal? ($query 'lang) "en")
              (equal? (header 'language) "en"))
          (update-person id body)
          (send-error 400 "Language Error" "Language not specified or not supported.")))))
```

### Querying SPARQL Endpoints

The provided [sparql-query](https://github.com/nathanielrb/s-sparql/blob/master/sparql-query.scm) module (part of s-sparql) provides functions for managing namespaces and querying SPARQL endpoints.

#### Escaping SPARQL Values

Three specific escape functions are provided:

```
(sparql-escape-string "value")
;; => "\"value\""

(sparql-escape-uri "http://example.org")
;; => "<http://example.org>"

(sparql-escape-boolean #f)
;; => "false"
```

Additionally, the more general `sparql-escape-literal` function can be used to escape typed literals, represented as cons pairs, where &lt;type&gt; can be a symbol or a string:

```
(sparql-escape-literal '("val" . <type>))
;; => "\"val\"^^<type>"
```

language-tagged strings, also represented  as cons pairs,  where @lang can be a symbol or string:

```
(sparql-escape-literal '("val" . @lang))
;; => "\"val\"@lang"
```
`sparql-escape-literal` can also take two arguments, a  list of sparql literals and a string to join them:

```
(sparql-escape-literal '("Cat" "Dog" "Mouse") ", ")
;; => "\"Cat\", \"Dog\", \"Mouse\""
```

Note that `(sparql-escape-boolean "true")` returns `"true"` (i.e., it handles string values) but `(sparql-escape-value "true")` returns `"\"true\""`, i.e., treats "true" as a regular string.

#### Running Queries

The two main query procedures are `sparql-select` and `sparql-update`.


```
(define-namespace animals "http://example.org/animals")

(sparql-select 
  "SELECT ?s ?food
   FROM ~A
   WHERE {
      ?s a ~A.
      ?s ~A ~A.
      ?s animals:eats ?food.
      ?s animals:isHungry ~A.
      ?s animals:lastFed ~A.
      ?s animals:says ~A.
    }" 
  (*default-graph*)
  'animals:Cat 
  (sparql-escape-uri "http://schema.org/title")
  (sparql-escape-string "Mr Cat")
  (sparql-escape-boolean #f)
  (sparql-escape-literal '("2017-06-24" . <http://www.w3.org/2001/XMLSchema#dateTime>))
  (sparql-escape-literal '("miaow" . @en)))

;; =>  '(((s . "http://example.org/animals/cat123") (food . "Whiskas"))
;;       ((s . "http://example.org/animals/cat003") (food . "Purina One")))
```

The special form `select-with-vars` wraps `sparql-select` with a `let` binding following the same naming. Its syntax is `(select-with-vars (vars ...) (query args ...) body)`.

```
(select-with-vars (s food)
  ("SELECT ?s ?food
    WHERE {
       ?s a ~A.
       ?s animals:isSpayed ~A.
       ?s ~A ~A.
       ?s animals:eats ?food
     }" 
   "animals:Cat"
   (sparql-escape-boolean #f)
   '<http://schema.org/title> ;; same as (sparql-escape-uri ...)
   (sparql-escape-string "Mr Cat"))

 `((cat . ((id . ,cat) (attributes . ,(conc "Likes " food))))))

;; => '(((cat . ((id . "http://example.org/animals/cat123") (attributes . "Likes Whiskas"))))
;;      ((cat . ((id . "http://example.org/animals/cat003") (attributes . "Likes Purina One")))))
```

In the above examples, JSON results are preprocessed by the function defined by the parameter *query-unpacker*. The default unpacker, as shown above, returns a list of association lists with bindings var/val pairs:

```
;; (*query-unpacker* sparql-bindings)  - default

(sparql-select query)

;; => '(((var1 . "string value") (var2 . 123)
;;       (var3 . "http://example.org/uri") (var4 . "2017-08-01")) ...)
```

Another unpacker, `typed-sparql-bindings` is defined to parse RDF datatypes to the `s-sparql` format:
n
```
(*query-unpacker* typed-sparql-bindings)

(sparql-select query)

;; => '(((var1 . "str-val") 
;;       (var2 . 123)
;;       (var3 . <http://example.org/uri>)
;;       (var4 . ("2017-08-01" . <http://www.w3.org/2001/XMLSchema#dateTime>))) ...)
```

To recover the unprocessed RDF JSON, we can also set `*query-unpacker*` to `string->json` for the Scheme representation of JSON, or `values` for the raw string:

```
(*query-unpacker* string->json)

(sparql-select query)

;; => '(((var1 . ((value "str-val") (type . "literal")))
;;       (var2 . ((value . "123") (type . "typed-literal") (datatype . "http://www.w3.org/2001/XMLSchema#integer")))
;;       (var3 . ((value . "http://example.org/uri") (type . "uri")))
;;       (var4 . ((value . "2017-08-01") (type . "typed-literal") (datatype . "http://www.w3.org/2001/XMLSchema#dateTime")))) ...)

(*query-unpacker* values)

(sparql-select query)

;; => "[ {\"var1\": { \"value\": ...} } ...]"
```
