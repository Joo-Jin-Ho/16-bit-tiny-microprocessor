# 16-bit-tiny-microprocessor
Design and implementation of a 16-bit tiny microprocessor using Verilog HDL

16-bit Tiny Microprocessor를 Verilog HDL을 이용하여 설계 및 구현한 프로젝트입니다. 기본적인 산술 연산, 메모리 접근, 분기 명령어를 지원하는 5-stage Pipeline 구조의 프로세서를 구현하고, 파이프라인 환경에서 발생하는 Data Hazard를 해결하기 위한 Forwarding 기법을 적용하는 것을 목표로 하였습니다.

프로세서는 IF, ID, EX, MEM, WB의 5단계 파이프라인 구조를 기반으로 설계되었으며, Execute 및 Decode 단계에 Forwarding Multiplexer와 Hazard Detection Logic을 구현하여 데이터 의존성으로 인한 성능 저하를 최소화하였습니다. 최종적으로 기능 시뮬레이션과 Testbench를 통해 모든 명령어가 정상적으로 동작함을 검증하였습니다.

# 🚀 프로젝트 개요
