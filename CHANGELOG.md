## [Unreleased]

## [0.3.2] = 2023-12-01

- The ActiveRecordAdapter is passing its unit tests
- Dropped the concept of an sqlite3 adapter since active record can be used to access sqlite3 databases as well as the big boys.

## [0.3.0] = 2023-11-28

- **Breaking change** The value of the parameters Hash for a keyword is now an Array instead of a single value.  The last value in the Array is always the most recent value used for the given keyword.  This was done to support the use of a Readline::History object editing in the [aia](https://github.com/MadBomber/aia) CLI tool

## [0.2.0] - 2023-11-21

- **Breaking change to FileSystemAdapter config process**
- added list and path as extra methods in FileSystemAdapter

## [0.1.0] - 2023-11-16

- Initial release using the FileSystemAdapter
