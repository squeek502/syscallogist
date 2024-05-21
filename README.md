syscallogist
============

> *syscallogy*: The study of syscalls.
>
> *syscallogist*: A program that studies syscalls.

An experiment in determining/cataloging the range of possible syscall behavior through empirical testing. The idea is:

- Write a program that (1) gets information about the execution environment (OS, filesystem, etc), and (2) runs a series of tests (e.g. calling various syscalls) and records the results.
- Run that program on many different operating systems/filesystems/etc and catalog the results in a database of some sort
- Use the resulting database to make various inferences about the behavior of syscalls (what errors are possible and when, what the range of possible values is, etc)

This is still in the *very* early stages. It currently only tests the behavior of `NtQueryInformationFile` on Windows, and only with a subset of possible `FILE_INFORMATION_CLASS` types.

Truncated example output:

```
NtQueryInformationFile: stdin_nul
  FileBasicInformation
    NTSTATUS: INVALID_INFO_CLASS
  FileStandardInformation
    NTSTATUS: SUCCESS
    AllocationSize: 0
    EndOfFile: 0
    NumberOfLinks: 1
    DeletePending: 0
    Directory: 0

NtQueryInformationFile: stdin_pipe
  FileBasicInformation
    NTSTATUS: SUCCESS
    CreationTime: 0
    LastAccessTime: 0
    LastWriteTime: 0
    ChangeTime: 0
    FileAttributes: 128
  FileStandardInformation
    NTSTATUS: SUCCESS
    AllocationSize: 8192
    EndOfFile: 0
    NumberOfLinks: 1
    DeletePending: 1
    Directory: 0

NtQueryInformationFile: stdin_close
  FileBasicInformation
    NTSTATUS: INVALID_HANDLE
  FileStandardInformation
    NTSTATUS: INVALID_HANDLE

NtQueryInformationFile: self_exe
  FileBasicInformation
    NTSTATUS: SUCCESS
    CreationTime: 133607567251975688
    LastAccessTime: 133607567258022339
    LastWriteTime: 133607567251505257
    ChangeTime: 133607567251995706
    FileAttributes: 32
  FileStandardInformation
    NTSTATUS: SUCCESS
    AllocationSize: 1323008
    EndOfFile: 1323008
    NumberOfLinks: 1
    DeletePending: 0
    Directory: 0
```

## Compiling & Usage

Last tested with Zig `0.13.0-dev.231+28476a5ee`. Only compiles/runs on Windows currently.

```
zig build
./zig-out/bin/syscallogist.exe
```
