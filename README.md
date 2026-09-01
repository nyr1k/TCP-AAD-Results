# TCP-AAD Experimental Framework

This repository contains the experimental setup, automation scripts, analysis notebooks, and results developed during my research internship on **TCP-AAD (Aggregation-Aware ACK Delaying)**.

The purpose of the repository is to reproduce and evaluate the TCP-AAD implementation in Linux and to analyze its behavior under different experimental configurations.

## Repository Structure

```text
.
├── analysis/
│   ├── *.ipynb
│   ├── plots/
│   ├── plots_multi_test_server/
│   └── plots_multi_test_server2/
│
├── results/
│   ├── main_test/
│   ├── multi_test_server/
│   └── multi_test_server2/
│
├── scripts/
│   ├── config.sh
│   ├── utils.sh
│   ├── run.sh
│   ├── run_main_test.sh
│   ├── run_main_test_server.sh
│   ├── run_main_test_server2.sh
│   ├── run_single_test.sh
│   ├── run_single_test2.sh
│   ├── launch_multi_test.sh
│   └── capture_metadata.sh
│
└── README.md
```

## 1. Experimental Setup

The experiments were conducted using Linux machines with a modified Linux kernel containing the TCP-AAD implementation.

The experimental workflow uses several standard Linux networking tools:

- **iperf3** — generation of TCP traffic and throughput measurement
- **tcpdump** — packet capture and network traffic analysis
- **tc** — traffic control and network configuration
- **Linux kernel tracing** — collection of kernel-level TCP events

The experiments were initially conducted using a single-server configuration and were later extended to a two-server configuration.

In the two-server configuration, **Server 1 and Server 2 generate traffic simultaneously toward the receiver**. Files and scripts containing the suffix `2` generally refer to **Server 2**, rather than a second version of the experiment.

## 2. Experiment Configurations

The `results/` directory contains data from the experimental configurations.

### `main_test`

Contains results from the original single-server experiment.

The experiment includes:

- `default`
- `tcpaad_20`
- `tcpaad_30`
- `tcpaad_50`

The `tcpaad_*` directories correspond to different TCP-AAD configurations.

### `multi_test_server`

Contains results associated with **Server 1** in the two-server experimental setup.

### `multi_test_server2`

Contains results associated with **Server 2** in the same two-server experimental setup.

The two servers were configured to run the experiment simultaneously so that their performance could be compared under the same network conditions.

A significant throughput difference was observed between the two servers. The experiments were repeated multiple times to determine whether this difference was caused by random variation. The discrepancy remained present across repeated runs.

## 3. Experiment Automation

The `scripts/` directory contains Bash scripts used to automate the experiments.

### Main scripts

- `run_main_test.sh` — runs the original single-server experimental procedure.
- `run_single_test.sh` — runs an individual test for the primary server.
- `run_single_test2.sh` — runs an individual test for **Server 2**.
- `run_main_test_server.sh` — runs the experimental procedure for **Server 1** in the two-server setup.
- `run_main_test_server2.sh` — runs the experimental procedure for **Server 2** in the two-server setup.
- `launch_multi_test.sh` — coordinates the multi-server experiment.
- `capture_metadata.sh` — collects experimental metadata.
- `config.sh` — contains experiment configuration parameters.
- `utils.sh` — contains common utility functions.
- `run.sh` — general experiment launcher.

The scripts were modified during the internship to automate the experimental procedure and support simultaneous experiments involving two servers.

## 4. Analysis

The `analysis/` directory contains Jupyter notebooks used to process and analyze the experimental data.

### Notebooks

- `analyze-main.ipynb` — main experimental data analysis.
- `analyse-debug.ipynb` — analysis of debugging data.
- `analyse-rate-change.ipynb` — analysis related to rate changes.
- `analyse-router.ipynb` — analysis of router-related measurements.
- `analyze-debug-modified.ipynb` — modified debugging analysis.
- `analyze-formulas.ipynb` — analysis involving the experimental formulas and calculations.

The notebooks were used to process the collected measurements and generate graphs for comparing the experimental configurations.

## 5. Generated Results

The analysis scripts generate several types of plots:

- **Throughput**
- **ACK count**
- **Packet aggregation**
- **Mean RTT**
- **PHY utilization**
- **Retransmissions**

The plots are organized according to the experimental data:

```text
analysis/plots/
analysis/plots_multi_test_server/
analysis/plots_multi_test_server2/
```

For the multi-server experiment, the directories with and without the `2` suffix correspond to **Server 1 and Server 2**, respectively.

## 6. Kernel Tracing

During the internship, kernel-level tracing was added to the TCP-AAD implementation to obtain more detailed information about the behavior of the TCP stack.

Tracing was used to observe events including:

- Layer 3 packet reception
- ACK generation timing
- Timeout-related events

The modified kernel was recompiled after adding the tracing instrumentation. Kernel traces were then collected using the Linux kernel tracing infrastructure.

The trace data was used to investigate the throughput discrepancy observed between Server 1 and Server 2 during the multi-server experiments.

## 7. Main Experimental Observation

The single-server and two-server experiments produced different performance characteristics.

During the two-server experiments, **Server 1 and Server 2 showed a significant and persistent throughput difference**, with one server achieving substantially lower throughput than the other. The overall throughput was also lower than in the single-server configuration.

The experiment was repeated multiple times to determine whether the discrepancy was caused by random variation. The behavior remained present across repeated runs, suggesting that the issue is reproducible and requires further investigation.

The collected results and kernel traces are preserved in this repository for further analysis.

## 8. Reproducing the Experiments

Before running the experiments, make sure the required networking tools are installed:

```bash
iperf3
tcpdump
tc
```

The experimental machines should also be configured with the appropriate TCP-AAD-enabled Linux kernel and network configuration.

Experiment parameters can be adjusted in:

```text
scripts/config.sh
```

The appropriate experiment script can then be executed from the `scripts/` directory.

**Note:** The scripts were developed for the specific experimental environment used during the research project. Network interface names, IP addresses, SSH configuration, and other environment-specific parameters may need to be adjusted before running them on another setup.

## 9. Research Outputs

The main outputs of the work contained in this repository are:

- TCP-AAD experimental environment and configuration.
- Automated scripts for conducting the experiments.
- Extended scripts supporting a two-server experimental setup.
- Experimental datasets from single-server and two-server configurations.
- Jupyter notebooks for processing and analyzing experimental data.
- Graphs visualizing throughput, RTT, ACK behavior, aggregation, retransmissions, and PHY utilization.
- Linux kernel tracing instrumentation for investigating TCP-AAD behavior.
- Documentation of the experimental methodology and observed results.

## 10. Notes

This repository represents the experimental work completed during my research internship.

The two-server configuration revealed a persistent throughput discrepancy between the servers that was not fully resolved during the internship. The collected experimental results and kernel trace data provide a basis for continuing the investigation.

**Naming convention:** In files and directories where the name ends in `2` (for example, `run_single_test2.sh`, `run_main_test_server2.sh`, or `multi_test_server2`), the `2` refers to **Server 2** in the two-server experimental configuration.# TCP-AAD-Results
