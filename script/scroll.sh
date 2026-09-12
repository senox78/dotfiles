#!/usr/bin/env bash

x_delta=0
y_delta=0
delta=2

case "$1" in
up | u)
  y_delta=-$delta
  ;;
down | d)
  y_delta=$delta
  ;;
left | l)
  x_delta=-$delta
  ;;
right | r)
  x_delta=$delta
  ;;
*)
  echo "Usage: $0 {up|down|left|right}"
  exit 1
  ;;
esac

for _ in {1..10}; do
  wlrctl pointer scroll "$y_delta" "$x_delta"
  sleep 0.003
done
