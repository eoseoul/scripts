## Test Environment

**NOTE: We tested on Ubuntu 16.04 only.**

## Script download
```bash
git clone https://github.com/eoseoul/scripts.git
```

## Modify configuration
```bash
cd bmt_client
vi bmt.conf
```

* **NOTE** Change `DATA_DIR` to current script directory.
* `ACCOUNT_CREATOR` is account for creating random test accounts.
* `CREATE_AMOUNT` should be more than token count * 400. If lower, it is impossible to issue enough token to random test accounts.
* `PDINFO` for block producer node information. Update `BPNAME`, `HOSTNAME` or `SERVERIP`, `HTTP_PORT`.
* `WLT` under `Local WALLET` section for number of locall wallets. You can increase or decrease them.
* If you want to compare your results with results from EOSeoul, don't change them.

## Preparation

Use command below to prepare test environment.
* Create random test accounts
* Issue tokens to random test accounts
* Create Job file
```bash
./bmt.sh prepare
```

## Test!

`run_job` divides all action commands into scripts with 500 commands each and executes as background bash scripts. So, if you want to stop running scripts, find its process and `kill` them all.

```bash
./bmt.sh run_job
```

## Check test results

Test results are mean transaction per second using first trx and last trx in Transaction_log.
If your test results are broken, it is probably because last transaction is aborted.
Then use trx values in Transaction_log.

```bash
./bmt.sh get_ret
```

## Recreate JOB

If you find flaws in Transfer JOB, recreate JOB file using command below.

```bash
./bmt.sh gen_job
```

## Clean your environment

```bash
./bmt.sh clean
```
