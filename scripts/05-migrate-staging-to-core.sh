#!/bin/bash

psql -U postgres -d registro_glacial -f ~/projects/registro_glacial/04-core-etl.sql
