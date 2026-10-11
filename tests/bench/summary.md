Cycles per call (run_bench.sh; best of five repetitions of 2·10⁷ calls).
Latency feeds each call's output into the next call's counter; throughput uses independent counters, as particles do.

| Machine | Compiler | Flags | `threefry2x32` latency | `threefry2x32` throughput | `threefry2x32_r` latency | empty call | Clock GHz | Date | Source |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| AMD Ryzen 7 5800X 8-Core Processor, Linux x86_64, Rocky Linux 9.8 (Blue Onyx) | GNU Fortran (GCC) 11.5.0 20240719 (Red Hat 11.5.0-14) | -O2 | 77.3 | 57.8 | 150.5 | 3.0 | 4.83 | 2026-10-10 | src 936d663d |
| AMD Ryzen 7 5800X 8-Core Processor, Linux x86_64, Rocky Linux 9.8 (Blue Onyx) | ifx (IFX) 2026.1.1 20260724 | -O2 | 49.0 | 33.0 | 172.8 | 4.0 | 4.83 | 2026-10-10 | src 936d663d |
| Apple M1 Pro, Darwin arm64 | GNU Fortran (Homebrew GCC 16.2.0) 16.2.0 | -O2 | 71.7 | 36.3 | 114.4 | 6.8 | 3.12 | 2026-10-10 | src 936d663d |
