# library-api

## Design decisions

  - A book can have only one active borrowing.
  - Books are soft deleted to keep their borrowing history.
  - Services raise errors that the controller maps to HTTP responses. With more services I would consider
  returning a Result object instead.

  ## Limitations

  - If the daily job does not run on a given day, that day's reminders are never sent.

  ## Ideas for improvement

  - Separate a book title from its physical copies, so that availability can be shown per title.
