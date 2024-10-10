package ethereum

import (
	"bufio"
	"crypto/ecdsa"
	"encoding/hex"
	"fmt"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/assert"
	"io"
	"log"
	"os"
	"strings"
	"testing"
)

var keys = []string{
	"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
	"0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
	"0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",
	"0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6",
	"0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a",
	"0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba",
	"0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e",
	"0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356",
	"0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97",
	"0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6",
	"0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
}

var keyFilePaths = []string{
	//"/Users/hanmengwei/Desktop/keys",
	"transfer/eth/keystore/keys",
	//"invoke/eth/keystore/keys",
	//"one_hundred_million/eth/keystore/keys-1",
	//"one_hundred_million/eth/keystore/keys-2",
	//"one_hundred_million/eth/keystore/keys-3",
	//"one_hundred_million/eth/keystore/keys-4",
	//"one_hundred_million/eth/keystore/keys-5",
	//"one_hundred_million/eth/keystore/keys-6",
	//"one_hundred_million/eth/keystore/keys-7",
	//"one_hundred_million/eth/keystore/keys-8",
	//"one_hundred_million/eth/keystore/keys-9",
	//"one_hundred_million/eth/keystore/keys-10",
	//"one_hundred_million/eth/keystore/keys-11",
	//"one_hundred_million/eth/keystore/keys-12",
	//"one_hundred_million/eth/keystore/keys-13",
	//"one_hundred_million/eth/keystore/keys-14",
	//"one_hundred_million/eth/keystore/keys-15",
	//"one_hundred_million/eth/keystore/keys-16",
	//"one_hundred_million/eth/keystore/keys-17",
	//"one_hundred_million/eth/keystore/keys-18",
	//"one_hundred_million/eth/keystore/keys-19",
	//"one_hundred_million/eth/keystore/keys-20",
}

var keyGeneratePaths = []string{
	//"transfer/eth/keystore/eth",
	//"erc20/eth/keystore/eth",
	//"uniswap/eth/keystore/eth",
	//"makerdao/eth/keystore/eth",
	//"compound/eth/keystore/eth",
	//"/Users/hanmengwei/Desktop/keys",
	//"one_hundred_million/eth/keystore/keys-1",
	//"one_hundred_million/eth/keystore/keys-2",
	//"one_hundred_million/eth/keystore/keys-3",
	//"one_hundred_million/eth/keystore/keys-4",
	//"one_hundred_million/eth/keystore/keys-5",
	//"one_hundred_million/eth/keystore/keys-6",
	//"one_hundred_million/eth/keystore/keys-7",
	//"one_hundred_million/eth/keystore/keys-8",
	//"one_hundred_million/eth/keystore/keys-9",
	//"one_hundred_million/eth/keystore/keys-10",
	//"one_hundred_million/eth/keystore/keys-11",
	//"one_hundred_million/eth/keystore/keys-12",
	//"one_hundred_million/eth/keystore/keys-13",
	//"one_hundred_million/eth/keystore/keys-14",
	//"one_hundred_million/eth/keystore/keys-15",
	//"one_hundred_million/eth/keystore/keys-16",
	//"one_hundred_million/eth/keystore/keys-17",
	//"one_hundred_million/eth/keystore/keys-18",
	//"one_hundred_million/eth/keystore/keys-19",
	//"one_hundred_million/eth/keystore/keys-20",
	"transfer/eth/keystore/keys",
}

const TotalAccount = 2063515

func TestAccount(t *testing.T) {
	for _, key := range keys {
		sk, err := crypto.HexToECDSA(strings.TrimPrefix(key, "0x"))
		assert.Nil(t, err)
		addr := crypto.PubkeyToAddress(sk.PublicKey)
		t.Logf("address is: %s, private key is: %s", addr.String(), key)
	}
}

// TestGenerateAccountAndAddr will generate a specified number of private keys and addresses, and store them in the appropriate location
// keys will be in keystore/keys
// and addresses will be in current location, which can be used for importing accounts by axiom-ledger cmd
func TestGenerateAccountAndAddr(t *testing.T) {
	for _, keyFilePath := range keyGeneratePaths {
		// keyfile like `transfer/eth/keystore/keys`
		keyFile, err := os.OpenFile(keyFilePath, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
		assert.Nil(t, err)

		// addrFile like `transfer-address` in current location
		pathParts := strings.Split(keyFilePath, "/")
		addrFileName := pathParts[0] + "-address"
		addrFile, err := os.OpenFile(addrFileName, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
		assert.Nil(t, err)

		var sk *ecdsa.PrivateKey
		for i := 0; i < TotalAccount; i++ {
			sk, err = crypto.GenerateKey()
			assert.Nil(t, err)

			// store private key
			privKey := hex.EncodeToString(crypto.FromECDSA(sk))
			_, err = keyFile.Write([]byte(privKey + "\n"))
			assert.Nil(t, err)

			// store address
			addr := crypto.PubkeyToAddress(sk.PublicKey).Hex()
			_, err = addrFile.Write([]byte(addr + "\n"))
			assert.Nil(t, err)
		}

		assert.Nil(t, keyFile.Close())
		t.Logf("Finished generating keys in %s", keyFilePath)

		assert.Nil(t, addrFile.Close())
		t.Logf("Finished generating addresses in %s", addrFileName)
	}
}

func TestGenerateAccount(t *testing.T) {
	var dstFile *os.File
	var err error
	for i, keyFilePath := range keyFilePaths {
		if i == 0 {
			dstFile, err = os.OpenFile(keyFilePath, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
			assert.Nil(t, err)

			var sk *ecdsa.PrivateKey
			for i := 0; i < TotalAccount; i++ {
				sk, err = crypto.GenerateKey()
				assert.Nil(t, err)

				//t.Logf("key is: %+v", *sk)
				privKey := hex.EncodeToString(crypto.FromECDSA(sk))
				//t.Logf("priv key: %s", privKey)

				_, err = dstFile.Write([]byte(privKey))
				assert.Nil(t, err)
				_, err = dstFile.Write([]byte("\n"))
				assert.Nil(t, err)
			}
			err = dstFile.Close()
			assert.Nil(t, err)
		} else {
			f, err := os.OpenFile(keyFilePath, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
			assert.Nil(t, err)
			_, err = io.Copy(f, dstFile)
			assert.Nil(t, err)
			err = f.Close()
			assert.Nil(t, err)
		}
	}
}
func TestGetAddress(t *testing.T) {
	//GetAddress("transfer/eth/keystore/keys", "one_hundred_million/eth/keystore/address_transfer.txt")
	GetAddress("erc20/eth/keystore/keys", "one_hundred_million/eth/keystore/address_erc20.txt")
	GetAddress("uniswap/eth/keystore/keys", "one_hundred_million/eth/keystore/address_uniswap.txt")
	GetAddress("compound/eth/keystore/keys", "one_hundred_million/eth/keystore/address_compound.txt")
	GetAddress("makerdao/eth/keystore/keys", "one_hundred_million/eth/keystore/address_makerdao.txt")
	//GetAddress("transfer/eth/keystore/keys", "transfer/eth/keystore/address.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-1", "one_hundred_million/eth/keystore/address-1.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-2", "one_hundred_million/eth/keystore/address-2.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-3", "one_hundred_million/eth/keystore/address-3.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-4", "one_hundred_million/eth/keystore/address-4.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-5", "one_hundred_million/eth/keystore/address-5.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-6", "one_hundred_million/eth/keystore/address-6.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-7", "one_hundred_million/eth/keystore/address-7.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-8", "one_hundred_million/eth/keystore/address-8.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-9", "one_hundred_million/eth/keystore/address-9.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-10", "one_hundred_million/eth/keystore/address-10.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-11", "one_hundred_million/eth/keystore/address-11.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-12", "one_hundred_million/eth/keystore/address-12.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-13", "one_hundred_million/eth/keystore/address-13.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-14", "one_hundred_million/eth/keystore/address-14.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-15", "one_hundred_million/eth/keystore/address-15.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-16", "one_hundred_million/eth/keystore/address-16.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-17", "one_hundred_million/eth/keystore/address-17.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-18", "one_hundred_million/eth/keystore/address-18.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-19", "one_hundred_million/eth/keystore/address-19.txt")
	//GetAddress("one_hundred_million/eth/keystore/keys-20", "one_hundred_million/eth/keystore/address-20.txt")

}

func TestWriteGenesis(t *testing.T) {
	//WriteConfig("erc20/eth/keystore/address.txt", "accounts_balance.txt")
	//WriteConfig("uniswap/eth/keystore/address.txt", "accounts_balance.txt")
	//WriteConfig("compound/eth/keystore/address.txt", "accounts_balance.txt")
	//WriteConfig("makerdao/eth/keystore/address.txt", "accounts_balance.txt")
	WriteConfig("transfer/eth/keystore/address.txt", "accounts_balance.txt")
	//WriteGenesisForTransfer("transfer/eth/keystore/eth", "accounts_balance.txt")
	//WriteGenesisForTransfer("transfer/eth/keystore/eth", "account_balance.txt")
}

func WriteConfig(fromPath string, destPath string) {
	file, err := os.Open(fromPath)
	if err != nil {
		fmt.Println("无法打开文件:", err)
		return
	}
	defer file.Close()

	// 创建一个 Scanner 用于逐行读取文件内容
	scanner := bufio.NewScanner(file)

	// 逐行读取文件内容并输出
	for scanner.Scan() {
		line := scanner.Text()
		fmt.Println(line)
		str := "[[accounts]]\naddress = '" + line + "'\nbalance = '1000000000000000000000000000000000000000'\n\n"

		// 打开文件，如果文件不存在则会创建，以追加模式打开
		dest, err := os.OpenFile(destPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err != nil {
			fmt.Println("无法打开文件:", err)
			return
		}
		defer dest.Close()

		// 写入字符串到文件
		_, err = dest.WriteString(str)
		if err != nil {
			fmt.Println("写入文件时出现错误:", err)
			return
		}
		err = dest.Close()
		if err != nil {
			log.Print(err)
		}

	}

	if err := scanner.Err(); err != nil {
		fmt.Println("读取文件时出现错误:", err)
	}
	err = file.Close()
	if err != nil {
		log.Print(err)
	}

}

func WriteGenesisForTransfer(filepath string, destPath string) {
	file, err := os.Open(filepath)
	if err != nil {
		fmt.Println("无法打开文件:", err)
		return
	}
	defer file.Close()

	// 创建一个 Scanner 用于逐行读取文件内容
	scanner := bufio.NewScanner(file)

	// 读取第一行信息
	if scanner.Scan() {
		firstLine := scanner.Text()
		dstFile, err := os.OpenFile(destPath, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
		if err != nil {
			log.Print(err)
		}

		sk, err := crypto.HexToECDSA(strings.TrimPrefix(firstLine, "0x"))
		if err != nil {
			log.Print(err)
		}

		addr := crypto.PubkeyToAddress(sk.PublicKey)
		str := "[[accounts]]\naddress = '" + addr.String() + "'\nbalance = '1000000000000000000000000000000000000000'"
		//log.Printf("address is: %s, private key is: %s", addr.String(), line)
		_, err = dstFile.Write([]byte(str))
		if err != nil {
			log.Print(err)
		}
		_, err = dstFile.Write([]byte("\n"))
		if err != nil {
			log.Print(err)
		}
		err = dstFile.Close()
		if err != nil {
			log.Print(err)
		}
	}

	if err := scanner.Err(); err != nil {
		fmt.Println("读取文件时出现错误:", err)
	}
}

func GetAddress(filepath string, dst string) {
	file, err := os.Open(filepath)
	if err != nil {
		fmt.Println("无法打开文件:", err)
		return
	}
	defer file.Close()

	// 创建一个 Scanner 用于逐行读取文件内容
	scanner := bufio.NewScanner(file)

	// 逐行读取文件内容并输出
	for scanner.Scan() {
		line := scanner.Text()
		//fmt.Println(line)
		dstFile, err := os.OpenFile(dst, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
		if err != nil {
			log.Print(err)
		}

		sk, err := crypto.HexToECDSA(strings.TrimPrefix(line, "0x"))
		if err != nil {
			log.Print(err)
		}

		addr := crypto.PubkeyToAddress(sk.PublicKey)
		//log.Printf("address is: %s, private key is: %s", addr.String(), line)
		_, err = dstFile.Write([]byte(addr.String()))
		if err != nil {
			log.Print(err)
		}
		_, err = dstFile.Write([]byte("\n"))
		if err != nil {
			log.Print(err)
		}
		err = dstFile.Close()
		if err != nil {
			log.Print(err)
		}

	}

	if err := scanner.Err(); err != nil {
		fmt.Println("读取文件时出现错误:", err)
	}
	err = file.Close()
	if err != nil {
		log.Print(err)
	}
}
func TestSplitAndSaveKeys(t *testing.T) {
	srcFile, err := os.Open("./eth")
	if err != nil {
		panic(err)
	}
	defer srcFile.Close()

	var keys []string
	scanner := bufio.NewScanner(srcFile)
	for scanner.Scan() {
		line := scanner.Text()
		keys = append(keys, line)
	}

	if err := scanner.Err(); err != nil {
		panic(err)
	}

	totalKeys := len(keys)
	partSize := totalKeys / 3

	part1 := keys[:partSize]
	part2 := keys[partSize : 2*partSize]
	part3 := keys[2*partSize:]

	paths := []string{
		"stability-erc20/eth/keystore/eth",
		"stability-transfer/eth/keystore/eth",
		"stability-uniswap/eth/keystore/eth"}

	for i, part := range [][]string{part1, part2, part3} {
		file, err := os.Create(paths[i])
		if err != nil {
			panic(err)
		}
		defer file.Close()

		for _, key := range part {
			_, err := file.WriteString(key + "\n")
			if err != nil {
				panic(err)
			}
		}
	}
}
