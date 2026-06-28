;; -*- no-byte-compile: t; lexical-binding: nil -*-
(define-package "orgit" "20250901.1810"
  "Support for Org links to Magit buffers."
  '((emacs  "27.1")
    (compat "30.1")
    (magit  "4.3")
    (org    "9.7"))
  :url "https://github.com/magit/orgit"
  :commit "8493c248081a9ed71ad6fd61e4d6b48c8a0039ec"
  :revdesc "8493c248081a"
  :keywords '("hypermedia" "vc")
  :authors '(("Jonas Bernoulli" . "emacs.orgit@jonas.bernoulli.dev"))
  :maintainers '(("Jonas Bernoulli" . "emacs.orgit@jonas.bernoulli.dev")))
