# litecord

Litecord is an open source implementation of Discord's backend and API in
Python.

This project is a rewrite of [litecord-reference].

[litecord-reference]: https://gitlab.com/lnmds/litecord-reference

## Install

- Python 3.6 or higher
- PostgreSQL
- [Pipenv]

[pipenv]: https://github.com/pypa/pipenv

```sh
$ git clone https://gitlab.com/luna/litecord.git && cd litecord

# Setup the database:
$ createdb litecord
$ psql -f schema.sql litecord

# Configure litecord:
$ cp config.example.py config.py

# Install all packages:
$ pipenv install --dev
```

## Running

Hypercorn is used to run litecord. By default, it will bind to `0.0.0.0:5000`.
You can use the `-b` option to change it (e.g. `-b 0.0.0.0:45000`).

Use `--access-log -` to output access logs to stdout.

```sh
$ pipenv run hypercorn run:app
```
