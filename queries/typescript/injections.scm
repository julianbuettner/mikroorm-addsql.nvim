;; extends

; MikroORM raw SQL migrations: this.addSql(`ALTER TABLE ...`) / addSql(`...`)
(call_expression
  function: [
    (identifier) @_name
    (member_expression property: (property_identifier) @_name)
  ]
  (#eq? @_name "addSql")
  arguments: (arguments
    . (template_string) @injection.content)
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
  (#set! injection.language "sql"))
