exception SqliteException of Sqlite3.Rc.t

module SqliteBackendF : functor(DBA : DbState.DbAccess) -> sig
  include DbState.StateBackend
end
