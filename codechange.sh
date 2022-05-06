#!/bin/bash
mv src srcold && \
mv srcnew src && \
git add .
git commit -m "update"
git push
