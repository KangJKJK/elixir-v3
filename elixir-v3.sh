#!/bin/bash

# 색깔 변수 정의
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[36m'
NC='\033[0m' # No Color

echo -e "${GREEN}Elixir-v3 노드 설치를 시작합니다.${NC}"

command_exists() {
    command -v "$1" &> /dev/null
}

echo ""

if command_exists nvm; then
    echo -e "${GREEN}NVM이 이미 설치되어 있습니다.${NC}"
else
    echo -e "${YELLOW}NVM을 설치하는 중입니다...${NC}"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # NVM 로드
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # NVM bash_completion 로드
fi

if command_exists node; then
    echo -e "${GREEN}Node.js가 이미 설치되어 있습니다: $(node -v)${NC}"
else
    echo -e "${YELLOW}Node.js를 설치하는 중입니다...${NC}"
    nvm install node
    nvm use node
    echo -e "${GREEN}Node.js가 설치되었습니다: $(node -v)${NC}"
fi

echo ""

echo -e "${BOLD}${CYAN}ethers 패키지 설치 확인 중...${NC}"
if ! npm list ethers &> /dev/null; then
    echo -e "${RED}ethers 패키지가 없습니다. ethers 패키지를 설치하는 중입니다...${NC}"
    npm install ethers
    echo -e "${GREEN}ethers 패키지가 성공적으로 설치되었습니다.${NC}"
else
    echo -e "${GREEN}ethers 패키지가 이미 설치되어 있습니다.${NC}"
fi

echo -e "${BOLD}${CYAN}Docker 설치 확인 중...${NC}"
if ! command_exists docker; then
    echo -e "${RED}Docker가 설치되어 있지 않습니다. Docker를 설치하는 중입니다...${NC}"
    sudo apt update && sudo apt install -y curl net-tools
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    echo -e "${GREEN}Docker가 성공적으로 설치되었습니다.${NC}"
else
    echo -e "${GREEN}Docker가 이미 설치되어 있습니다.${NC}"
fi

echo -e "${BOLD}${CYAN}검증자 지갑 생성 중...${NC}"
cat << 'EOF' > generate_wallet.js
const { Wallet } = require('ethers');
const fs = require('fs');

const wallet = Wallet.createRandom();
const mnemonic = wallet.mnemonic.phrase;
const address = wallet.address;
const privateKey = wallet.privateKey;

const walletData = `
Mnemonic: ${mnemonic}
Address: ${address}
Private Key: ${privateKey}
`;

const filePath = 'validator_wallet.txt';
fs.writeFileSync(filePath, walletData);

console.log('');
console.log('검증자 지갑 니모닉 구문:', mnemonic);
console.log('검증자 지갑 주소:', address);
console.log('검증자 지갑 개인 키:', privateKey);
console.log('\x1B[32m지갑 자격 증명이 \x1b[35m validator_wallet.txt\x1B[0m에 저장되었습니다.');
EOF

node generate_wallet.js
echo ""

ENV_FILE="validator.env"

echo -e "${BOLD}${CYAN}${ENV_FILE} 파일 생성 중...${NC}"
echo "ENV=testnet-3" > $ENV_FILE
IP_ADDRESS=$(curl -s ifconfig.me)
echo "STRATEGY_EXECUTOR_IP_ADDRESS=$IP_ADDRESS" >> $ENV_FILE
echo ""

read -p "검증자 이름을 입력하세요 : " DISPLAY_NAME
echo "STRATEGY_EXECUTOR_DISPLAY_NAME=$DISPLAY_NAME" >> $ENV_FILE

read -p "검증자 보상을 받을 EVM지갑 주소를 입력하세요: " BENEFICIARY
echo "STRATEGY_EXECUTOR_BENEFICIARY=$BENEFICIARY" >> $ENV_FILE
echo ""
PRIVATE_KEY=$(grep "Private Key:" validator_wallet.txt | awk -F': ' '{print $2}' | sed 's/^0x//')
VALIDATOR_ADDRESS=$(grep "Address:" validator_wallet.txt | awk -F': ' '{print $2}')
echo "SIGNER_PRIVATE_KEY=$PRIVATE_KEY" >> $ENV_FILE

echo ""
echo -e "${BOLD}${CYAN}${ENV_FILE} 파일이 다음 내용으로 생성되었습니다:${NC}"
cat $ENV_FILE
echo ""

echo -e "${BOLD}${YELLOW}1. 해당 주소로 이동하세요: https://testnet-3.elixir.xyz/${NC}"
echo -e "${BOLD}${YELLOW}2. Sepolia Ethereum이 있는 지갑을 연결하세요 (이 지갑은 검증자 지갑 주소가 아니어야 합니다).${NC}"
echo -e "${BOLD}${YELLOW}3. Sepolia에서 MOCK Elixir 토큰을 발행하세요${NC}"
echo -e "${BOLD}${YELLOW}4. MOCK 토큰을 스테이킹하세요${NC}"
echo -e "${BOLD}${YELLOW}5. 이제 커스텀 검증자를 클릭하고 검증자 지갑 주소: $VALIDATOR_ADDRESS를 입력하세요.${NC}"
echo ""

read -p "위 단계를 완료하셨나요? (y/n): " response
if [[ "$response" =~ ^[yY]$ ]]; then
    echo -e "${BOLD}${CYAN}Elixir Protocol Validator 이미지 생성 중...${NC}"
    docker pull elixirprotocol/validator:v3
else
    echo -e "${RED}작업이 완료되지 않았습니다. 스크립트를 종료합니다.${NC}"
    exit 1
fi

echo ""
echo -e "${BOLD}${CYAN}Docker 실행 중...${NC}"
docker run -d --env-file validator.env --name elixir -p 17690:17690 --restart unless-stopped elixirprotocol/validator:v3
echo ""

echo -e "${GREEN}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요.${NC}"
echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"

