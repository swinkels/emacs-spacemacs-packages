;; -*- no-byte-compile: t; lexical-binding: nil -*-
(define-package "orgit" "20251123.1801"
  "Support for Org links to Magit buffers."
  '((emacs    "28.1")
    (compat   "30.1")
    (cond-let "0.2")
    (magit    "4.4")
    (org      "9.7"))
  :url "https://github.com/magit/orgit"
  :commit "0444b8659620e5100ab8d09694c6ffe6841b24cd"
  :revdesc "0444b8659620"
  :keywords '("hypermedia" "vc")
  :authors '(("Jonas Bernoulli" . "emacs.orgit@jonas.bernoulli.dev"))
  :maintainers '(("Jonas Bernoulli" . "emacs.orgit@jonas.bernoulli.dev")))
