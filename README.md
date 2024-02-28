# Library Catalogue
---

## About
This application mimics a website that my local library actually uses. Therefore, parts of the application may imply some real-world actions being taken place:

There are two roles (*Please refer to the login information below to access the accounts*):
  1. `admin` - a librarian. Full access
  2. `user` - you! A bookworm... who goes to a library to check out books. Limited access

General flow:
  1. User visits website and places a reservation on a book
  2. Reservation made awaits confirmation from librarian(admin) who would, in the real world, place a copy of the book in a location where it is ready for pickup. They would notify to the user that the book is available for pickup.
  3. User would visit library in person to collect the book
  4. The librarian would scan a barcode which triggers the book in the system to be marked as 'checked out'
  5. When the user is finished with the book, they may return the book in person. The librarian is able to scan the book and mark it as 'returned'

Note the roles
* admin
  * check out books
  * return books

* user
  * reserve books
  * cancel book reservations

---

### My Environment

**Ruby version:** ruby v 3.1.3
**Browser:** Google Chrome Version 114.0.5735.199
**PostgreSQL:** PostgreSQL 13.11

---

### How to Install
  1. Unzip the project to a desired location on your computer.

  2. Make sure you are using ruby version 3.1.3.

  3. Run the rest of the commands from the project directory.
  ```
    cd /path/to/Library_Catalogue
  ```

  4. Run the following command in your terminal to ensure all of the gems are installed on your machine.
  ```
    bundle install
  ```
  5. (Make sure you have PostgreSQL installed on your machine) Run the following command to set up the database and its seed data.
  ```
    createdb library
    psql -d library < schema.sql
  ```

## Run after installation

  1. Run the following command in your terminal in order to start the application
  ```
    bundle exec ruby library_catalogue.rb
  ```

  2. Connect to `localhost:4567` through your browser

---

## Login Information

You may use the following to access pre-registered accounts

**admin**
  username: `admin`
  password: `letmein`

**users**
  username: `catchemall999`
  password: `password`

  username: `iwilldominatetheworld`
  password: `password`

  username: `foo_bar_baz`
  password: `password`

---
*Note about a project requirement not addressed:*
> When deleting a row from a table, be sure to delete all data rows in other tables that depend on that row.

*This does not apply to my application due to the nature of the relationship between `books` and `users`.*