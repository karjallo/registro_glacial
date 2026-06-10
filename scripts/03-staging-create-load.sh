#!/bin/bash

psql -U postgres -d registro_glacial -f ~/projects/registro_glacial/01-staging-ddl.sql
psql -U postgres -d registro_glacial -f ~/projects/registro_glacial/02-staging-etl.sql
