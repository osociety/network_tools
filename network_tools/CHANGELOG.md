# Change Log

## 3.0.3

Testing CI/CD for dart package publish github action

## 3.0.2

Testing CI/CD for dart package publish github action

## 3.0.1

Testing CI/CD for dart package publish github action

## 3.0.0

**Breaking change** Change most of the methods names

    * HostScanner.discover to HostScanner.getAllPingableDevices
    * HostScanner.discoverPort to HostScanner.scanDevicesForSinglePort
    * PortScanner.discover to PortScanner.scanPortsForSingleDevice

Ip field in ActiveHost is now InternetAddress type instead of string which improve handling of IPv6.

ActiveHost now contains host name of the address if exist.

Better naming of methods

Bug fixes and improvements

## 2.1.0

Added partly support for searching mdns devices.

## 2.0.0

**Breaking change** Bump minimum dart version to 2.17.0.

Updated dart_ping package version to 7.0.1.

Updated test package version to 1.21.4.

## 1.0.8

Fixes

Add logs using logging package #13.

Even more points in pub.dev page #20.

## 1.0.7

Fixed

Saving the response time from each device #9.

Example crash on Windows #14.

Bump package version #15.

## 0.0.6

Resolved issue #9 and #10.

## 0.0.5

Resolved issue #1.

## 0.0.4

Single and Custom Port Scan added.

## 0.0.3

Subnet and Port range added.

## 0.0.2

Added example and followed pub conventions.

## 0.0.1

PortScanner and HostScanner.
