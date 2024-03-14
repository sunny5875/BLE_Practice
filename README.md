# BLE_Practice
2024, bluetooth low energy swift 테스트 앱

### 리서치 세부사항
- apple 공식 레퍼런스에 있는 예시에서 원하는 부분을 수정하면서 진행
- 진행한 예시는 Bluetooth low energy를 이용해서 진행
- 기존 블루투스보다 저전력으로 연결이 가능한 기술

### 블루투스 기본 구조
![image](https://github.com/sunny5875/BLE_Practice/assets/55349553/5eecf333-b9e5-4e38-8963-4680b362db37)

central: 연결할 기기들을 스캔하고 연결하는 중앙 디바이스
- 이 때 연결할 기기는 특정 service(UUID)를 가진 디바이스 리스트이므로 유니와플 앱만 가진 기기만을 검색할 수 있음

peripheral: 블루투스로 연결할 주변기기, central에게 연결을 요청하는 형태

### 주고 받는 방식
peripheral에서 데이터를 작성한 후에 끝에 EOM같은 메세지가 끝나는 의미의 토큰을 전달한다면 central에서는 메세지를 전부 받았다라고 인식하여 그 때 메세지를 가지고 검증 하면 됨
메세지 포맷은 현재 Byte array이므로 파일도 가능할 것으로 보이긴 하나 용량에 따른 테스트 필요

### 과정
1. 받을 사람은 은 기기들을 스캔하는 화면을 킨다
2. 보낼 사람은 보낼 데이터를 세팅한 후에 요청버튼을 누른다
3. 받을 사람은 나오는 주변 기기 리스트중에 하나를 선택한다(or 내부적으로 알아서 모두 연결 가능)
4. 보낼 사람은 연결된 상태라면 데이터를 전송한다
5. 받을 사람은 해당 데이터를 수신한다

### 참고 자료
[Transferring Data Between Bluetooth Low Energy Devices | Apple Developer Documentation](https://developer.apple.com/documentation/corebluetooth/transferring_data_between_bluetooth_low_energy_devices)https://developer.apple.com/documentation/corebluetooth/transferring_data_between_bluetooth_low_energy_devices
