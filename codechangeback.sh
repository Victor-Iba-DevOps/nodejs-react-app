#!/bin/bash
mv src srcnew && \
mv srcold src
git add .
git commit -m "update"
git push