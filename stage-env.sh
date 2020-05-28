#!/bin/sh

# Export Docker secrets as environment variables without displaying any errors / messages
export $(grep -vH --null '^#' /run/secrets/* | tr '\0' '=' | sed 's/^\/run\/secrets\///g')