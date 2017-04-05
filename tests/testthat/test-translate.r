context("translate")

<<<<<<< HEAD
test_that("logical values are converted to 0/1/NULL", {
  expect_equal(translate_sql(FALSE), sql("0"))
  expect_equal(translate_sql(TRUE), sql("1"))
  expect_equal(translate_sql(NA), sql("NULL"))
})

=======
>>>>>>> hadley/master
test_that("dplyr.strict_sql = TRUE prevents auto conversion", {
  old <- options(dplyr.strict_sql = TRUE)
  on.exit(options(old))

  expect_equal(translate_sql(1 + 2), sql("1.0 + 2.0"))
  expect_error(translate_sql(blah(x)), "could not find function")
})

test_that("Wrong number of arguments raises error", {
  expect_error(translate_sql(mean(1, 2), window = FALSE), "Invalid number of args")
})

test_that("Named arguments generates warning", {
  expect_warning(translate_sql(mean(x = 1), window = FALSE), "Named arguments ignored")
})

test_that("between translated to special form (#503)", {
  out <- translate_sql(between(x, 1, 2))
  expect_equal(out, sql('"x" BETWEEN 1.0 AND 2.0'))
})

test_that("is.na and is.null are equivalent", {
  # Needs to be wrapped in parens to ensure correct precedence
  expect_equal(translate_sql(is.na(x)), sql('(("x") IS NULL)'))
  expect_equal(translate_sql(is.null(x)), sql('(("x") IS NULL)'))

  expect_equal(translate_sql(x + is.na(x)), sql('"x" + (("x") IS NULL)'))
  expect_equal(translate_sql(!is.na(x)), sql('NOT((("x") IS NULL))'))
})

test_that("if translation adds parens", {
  expect_equal(
    translate_sql(if (x) y),
    sql('CASE WHEN ("x") THEN ("y") END')
  )
  expect_equal(
    translate_sql(if (x) y else z),
    sql('CASE WHEN ("x") THEN ("y") ELSE ("z") END')
  )
})

test_that("if and ifelse use correctly named arguments",{
  exp <- translate_sql(if (x) 1 else 2)

  expect_equal(translate_sql(ifelse(test = x, yes = 1, no = 2)), exp)
  expect_equal(translate_sql(if_else(condition = x, true = 1, false = 2)), exp)
})


test_that("all forms of if translated to case statement", {
  expected <- sql('CASE WHEN ("x") THEN (1) ELSE (2) END')

  expect_equal(translate_sql(if (x) 1L else 2L), expected)
  expect_equal(translate_sql(ifelse(x, 1L, 2L)), expected)
  expect_equal(translate_sql(if_else(x, 1L, 2L)), expected)
})

test_that("pmin and pmax become min and max", {
  expect_equal(translate_sql(pmin(x, y)), sql('MIN("x", "y")'))
  expect_equal(translate_sql(pmax(x, y)), sql('MAX("x", "y")'))
})

test_that("%in% translation parenthesises when needed", {
  expect_equal(translate_sql(x %in% 1L), sql('"x" IN (1)'))
  expect_equal(translate_sql(x %in% 1:2), sql('"x" IN (1, 2)'))
  expect_equal(translate_sql(x %in% y), sql('"x" IN "y"'))
})

test_that("n_distinct can take multiple values", {
  expect_equal(
    translate_sql(n_distinct(x), window = FALSE),
    sql('COUNT(DISTINCT "x")')
  )
  expect_equal(
    translate_sql(n_distinct(x, y), window = FALSE),
    sql('COUNT(DISTINCT "x", "y")')
  )
})

test_that("na_if is translated to NULL_IF", {
  expect_equal(translate_sql(na_if(x, 0L)), sql('NULL_IF("x", 0)'))
})

test_that("connection affects quoting character", {
  dbTest <- src_sql("test", con = simulate_test())
  testTable <- tbl_sql("test", src = dbTest, from = ident("table1"))

  out <- select(testTable, field1)
  expect_match(sql_render(out), "^SELECT `field1` AS `field1`\nFROM `table1`$")
})



# string functions --------------------------------------------------------

test_that("different arguments of substr are corrected", {
  expect_equal(translate_sql(substr(x, 3, 4)), sql('substr("x", 3, 2)'))
  expect_equal(translate_sql(substr(x, 3, 3)), sql('substr("x", 3, 1)'))
  expect_equal(translate_sql(substr(x, 3, 2)), sql('substr("x", 3, 0)'))
  expect_equal(translate_sql(substr(x, 3, 1)), sql('substr("x", 3, 0)'))
})

