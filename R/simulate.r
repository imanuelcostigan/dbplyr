simulate_test <- function() {
  structure(list(), class = c("DBITestConnection", "DBIConnection"))
}

db_query_fields.DBITestConnection <- function(con, sql, ...) {
  c("field1")
}

sql_escape_ident.DBITestConnection <- function(con, x) {
  sql_quote(x, "`")
}

# DBI connections --------------------------------------------------------------

simulate_dbi <- function() {
  structure(
    list(),
    class = "DBIConnection"
  )
}

<<<<<<< HEAD
=======
simulate_sqlite <- function() {
  structure(
    list(),
    class = c("SQLiteConnection", "DBIConnection")
  )
}
>>>>>>> hadley/master

simulate_postgres <- function() {
  structure(
    list(),
    class = c("PostgreSQLConnection", "DBIConnection")
  )
}
<<<<<<< HEAD

=======
>>>>>>> hadley/master
