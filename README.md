# 16-bit-tiny-microprocessor
Design and implementation of a 16-bit tiny microprocessor using Verilog HDL

16-bit Tiny Microprocessor를 Verilog HDL을 이용하여 설계 및 구현한 프로젝트입니다. 기본적인 산술 연산, 메모리 접근, 분기 명령어를 지원하는 5-stage Pipeline 구조의 프로세서를 구현하고, 파이프라인 환경에서 발생하는 Data Hazard를 해결하기 위한 Forwarding 기법을 적용하는 것을 목표로 하였습니다.

프로세서는 IF, ID, EX, MEM, WB의 5단계 파이프라인 구조를 기반으로 설계되었으며, Execute 및 Decode 단계에 Forwarding Multiplexer와 Hazard Detection Logic을 구현하여 데이터 의존성으로 인한 성능 저하를 최소화하였습니다. 최종적으로 기능 시뮬레이션과 Testbench를 통해 모든 명령어가 정상적으로 동작함을 검증하였습니다.

# 🚀 프로젝트 개요
구현된 16-bit Tiny Microprocessor는 5-stage Pipeline 구조를 기반으로 동작합니다. 명령어는 IF, ID, EX, MEM, WB 단계를 순차적으로 거치며, 산술 연산, 메모리 접근, 분기 명령어를 수행합니다. 파이프라인 구조에서 발생하는 Data Hazard를 해결하기 위해 Forwarding 기법을 적용하였습니다. Execute 단계와 Decode 단계에 Forwarding Multiplexer를 추가하여 이전 명령어의 결과를 필요한 단계로 직접 전달하고, 불필요한 stall을 최소화하도록 설계하였습니다.

최종적으로 Verilog HDL로 구현한 tinyCPU.v를 기능 시뮬레이션과 Testbench를 통해 검증하였으며, 모든 명령어 테스트가 정상적으로 통과하는 것을 확인하였습니다.
<img width="1460" height="676" alt="image" src="https://github.com/user-attachments/assets/3cbffda4-173f-4820-bcb6-0cd12c4486fa" />

# Datapath Stage
1. IF (Instruction Fetch) : 명령어 메모리에서 명령어를 읽고 PC를 갱신
2. ID (Instruction Decode) : 명령어 해석 및 레지스터 값 읽기
3. EX (Execute) : ALU 연산, 주소 계산, 분기 조건 판단
4. MEM (Memory Access) : 데이터 메모리 읽기/쓰기 수행
5. WB (Write Back) : 연산 결과를 레지스터 파일에 저장

# Data Hazard 해결
Forwarding 기법 : 파이프라인 구조에서는 앞선 명령어의 결과가 아직 WB 단계에 도달하지 않았는데, 바로 다음 명령어가 그 결과를 필요로 하는 경우 Data Hazard가 발생합니다. 이를 해결하기 위해 Forwarding 기법을 적용하여, 연산 결과를 Register File에 저장될 때까지 기다리지 않고 필요한 단계로 직접 전달합니다.

* 동작 과정

1. Data Hazard 감지
현재 명령어가 사용하는 source register와 이전 명령어가 값을 저장할 destination register를 비교합니다. 두 register 번호가 같으면 현재 명령어가 이전 명령어의 결과를 필요로 한다고 판단합니다.

2. Forwarding 경로 선택
필요한 값이 어느 단계에 있는지 확인합니다. ALU 연산 결과는 EX/MEM 단계에서 바로 사용할 수 있고, Write Back 단계까지 진행된 값은 WB 단계에서 가져올 수 있습니다.

3. Execute 단계로 값 전달
ALU 입력 앞에 있는 Forwarding Multiplexer가 기존 register 값을 사용할지, 아니면 이전 pipeline stage의 결과를 사용할지 선택합니다. 이를 통해 현재 명령어는 stall 없이 바로 올바른 operand를 사용할 수 있습니다.

4. Decode 단계에서 분기 명령어 처리
조건 분기 명령어인 JZ는 ID 단계에서 조건값을 확인해야 하므로, Decode 단계에도 Forwarding 경로를 추가합니다. 이를 통해 분기 판단에 필요한 값을 이전 명령어로부터 직접 전달받을 수 있습니다.

5. Pipeline Stall 최소화
대부분의 ALU 연산 간 Data Hazard는 Forwarding만으로 해결할 수 있어 추가적인 stall 없이 명령어를 계속 실행할 수 있습니다. 다만 load-use hazard처럼 메모리에서 읽은 값이 너무 늦게 준비되는 경우에는 stall이 필요할 수 있습니다.
