## 실행 환경

**Ubuntu 16.04 기준으로 테스트를 진행할 수 있습니다.**

## Script download
```bash
git clone https://github.com/eoseoul/scripts.git
```

## 설정 수정
```bash
cd bmt_client
vi bmt.conf
```

* DATA_DIR 경로를 현재 스크립트 파일의 경로로 수정합니다.  (매우 중요)
* ACCOUNT_CREATOR는 랜덤 계정을 생성할 생성자이며 CREATE_AMOUNT의 코인 개수 * 400개 이상의 코인이 존재해야 합니다. (부족하면 랜덤 계정에 코인 지급 불가)
* PDINFO는 테스트 하고자 하는 BP Node의 정보를 입력해야하며, BPNAME, HOSTNAME 또는 SERVERIP, HTTP_PORT정보를 입력하면 됩니다. 
* Local WALLET Config의 WLT 항목은 생성하고자 하는 로컬 WALLET 개수이며, 줄이거나 늘릴 수 있습니다. 
* 기존 EOSeoul과의 테스트 결과 비교를 원하실 경우 수정하지 마시기 바랍니다. 

## 준비

아래와 같이 스크립트를 실행하여 테스트를 위한 랜덤 계정 생성, 코인 전달, Job 파일을 생성하시기 바랍니다. 
```bash
./bmt.sh prepare
```

## 테스트

run_job을 실행하게되면 joblist에 등록된 명령을 500개 단위로 나누어 Background Bash 스크립트로 실행 합니다. 따라서 도중에 중지하고자 할 경우 별도의 Terminal 창을 이용하여 해당 작업을 kill 명령으로 중지 하시기 바랍니다. 

```bash
./bmt.sh run_job
```

## 테스트 결과 확인

테스트 결과는 Transaction_log에 기록된 첫 trx와 마지막 trx를 기준으로 평균 처리량을 출력합니다. 

만약 테스트 결과가 제대로 출력되지 않는 경우 마지막 트랜잭션이 정상적으로 처리되지 않았을 가능성이 높습니다. 

로그의 trx값을 기준으로 조회해보시기 바랍니다.  

```bash
./bmt.sh get_ret
```

## JOB 재생성 

기존 실행한 Transfer JOB에 문제가 있다고 판단될 경우 아래와 같이 JOB파일을 재생성하세요. 

```bash
./bmt.sh gen_job
```

## 작업 후 정리

```bash
./bmt.sh clean
```
