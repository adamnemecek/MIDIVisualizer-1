//******************************************************************************
//
// MIDITrail / MTPianoKeyboardDesign
//
// ピアノキーボードデザインクラス
//
// Copyright (C) 2010-2013 WADA Masashi. All Rights Reserved.
//
//******************************************************************************

// MEMO:
// キーボードの基本配置座標
//
//  +y   +z
//  |    /
//  |   / +-#-#-+-#-#-#-+------
//  |  / / # # / # # # / ...
//  | / / / / / / / / / ...
//  |/ +-+-+-+-+-+-+-+------
// 0+------------------------ +x

#import "OGLUtil.h"
#import "SMIDILib.h"


//******************************************************************************
// ピアノキーボードデザインクラス
//******************************************************************************
class MTPianoKeyboardDesign
{
public:
	
	//キー種別
	//  黒鍵は白鍵と白鍵の中心から微妙にずれて配置されている
	//  このため白鍵の形はCからBまですべて異なる
	enum KeyType {
		KeyWhiteC,	//白鍵C
		KeyWhiteD,	//白鍵D
		KeyWhiteE,	//白鍵E
		KeyWhiteF,	//白鍵F
		KeyWhiteG,	//白鍵G
		KeyWhiteA,	//白鍵A
		KeyWhiteB,	//白鍵B
		KeyBlack	//黒鍵
	};
	
	//発音中キー色種別
	enum ActiveKeyColorType {
		DefaultColor,	//デフォルト色
		NoteColor		//ノート色
	};
	
public:
	
	MTPianoKeyboardDesign(void);
	virtual ~MTPianoKeyboardDesign(void);
	
	//初期化
	int Initialize(NSString* pSceneName, SMSeqData* pSeqData);
	
	//ポート原点座標取得
	float GetPortOriginX(unsigned char portNo);
	float GetPortOriginY(unsigned char portNo);
	float GetPortOriginZ(unsigned char portNo);
	
	//キー種別取得
	KeyType GetKeyType(unsigned char noteNo);
	
	//キー中心X座標取得
	float GetKeyCenterPosX(unsigned char noteNo);
	
	//白鍵配置間隔取得
	float GetWhiteKeyStep();
	
	//白鍵横サイズ取得
	float GetWhiteKeyWidth();
	
	//白鍵高さ取得
	float GetWhiteKeyHeight();
	
	//白鍵長さ取得
	float GetWhiteKeyLen();
	
	//黒鍵横サイズ取得
	float GetBlackKeyWidth();
	
	//黒鍵高さ取得
	float GetBlackKeyHeight();
	
	//黒鍵傾斜長さ取得
	float GetBlackKeySlopeLen();
	
	//黒鍵長さ取得
	float GetBlackKeyLen();
	
	//キー間隔サイズ取得
	float GetKeySpaceSize();
	
	//キー押下回転中心Y軸座標取得
	float GetKeyRotateAxisXPos();
	
	//キー押下回転角度
	float GetKeyRotateAngle();
	
	//キー下降時間取得(msec)
	unsigned long GetKeyDownDuration();
	
	//キー上昇時間取得(msec)
	unsigned long GetKeyUpDuration();
	
	//ピッチベンドキーボードシフト量取得
	float GetPitchBendShift(short pitchBendValue, unsigned char pitchBendSensitivity);
	
	//ノートドロップ座標取得
	float GetNoteDropPosZ(unsigned char noteNo);
	
	//白鍵カラー取得
	OGLCOLOR GetWhiteKeyColor();
	
	//黒鍵カラー取得
	OGLCOLOR GetBlackKeyColor();
	
	//発音中キーカラー取得
	OGLCOLOR GetActiveKeyColor(
			unsigned char noteNo,
			unsigned long elapsedTime,
			OGLCOLOR* pNoteColor = NULL
		);
	
	//白鍵テクスチャ座標取得
	void GetWhiteKeyTexturePosTop(
			unsigned char noteNo,
			OGLVECTOR2* pTexPos0,
			OGLVECTOR2* pTexPos1,
			OGLVECTOR2* pTexPos2,
			OGLVECTOR2* pTexPos3,
			OGLVECTOR2* pTexPos4,
			OGLVECTOR2* pTexPos5,
			OGLVECTOR2* pTexPos6,
			OGLVECTOR2* pTexPos7
		);
	void GetWhiteKeyTexturePosFront(
			unsigned char noteNo,
			OGLVECTOR2* pTexPos0,
			OGLVECTOR2* pTexPos1,
			OGLVECTOR2* pTexPos2,
			OGLVECTOR2* pTexPos3
		);
	void GetWhiteKeyTexturePosSingleColor(
			unsigned char noteNo,
			OGLVECTOR2* pTexPos
		);
	
	//黒鍵テクスチャ座標取得
	void GetBlackKeyTexturePos(
			unsigned char noteNo,
			OGLVECTOR2* pTexPos0,
			OGLVECTOR2* pTexPos1,
			OGLVECTOR2* pTexPos2,
			OGLVECTOR2* pTexPos3,
			OGLVECTOR2* pTexPos4,
			OGLVECTOR2* pTexPos5,
			OGLVECTOR2* pTexPos6,
			OGLVECTOR2* pTexPos7,
			OGLVECTOR2* pTexPos8,
			OGLVECTOR2* pTexPos9,
			bool isColored = false
		);
	void GetBlackKeyTexturePosSingleColor(
			unsigned char noteNo,
			OGLVECTOR2* pTexPos,
			bool isColored = false
		);
	
	//キーボード基準座標取得
	OGLVECTOR3 GetKeyboardBasePos(unsigned char portNo, unsigned char chNo);
	
	//キーボード最大表示数取得
	unsigned long GetKeyboardMaxDispNum();
	
	//キー表示範囲取得
	unsigned char GetKeyDispRangeStart();
	unsigned char GetKeyDispRangeEnd();
	bool IsKeyDisp(unsigned char noteNo);
	
private:
	
	//キー情報
	typedef struct {
		KeyType keyType;
		float keyCenterPosX;
	} MTKeyInfo;
	
private:
	
	//キー情報配列
	MTKeyInfo m_KeyInfo[SM_MAX_NOTE_NUM];
	
	//ポート情報
	SMPortList m_PortList;
	unsigned char m_PortIndex[SM_MAX_PORT_NUM];
	
	//スケール情報
	float m_WhiteKeyStep;
	float m_WhiteKeyWidth;
	float m_WhiteKeyHeight;
	float m_WhiteKeyLen;
	float m_BlackKeyWidth;
	float m_BlackKeyHeight;
	float m_BlackKeySlopeLen;
	float m_BlackKeyLen;
	float m_KeySpaceSize;
	float m_NoteDropPosZ4WhiteKey;
	float m_NoteDropPosZ4BlackKey;
	float m_BlackKeyShiftCDE;
	float m_BlackKeyShiftFGAB;
	
	//キー回転情報
	float m_KeyRotateAxisXPos;
	float m_KeyRotateAngle;
	int m_KeyDownDuration;
	int m_KeyUpDuration;
	
	//キーボード配置情報
	float m_KeyboardStepY;
	float m_KeyboardStepZ;
	int m_KeyboardMaxDispNum;
	
	//キー色情報
	OGLCOLOR m_WhiteKeyColor;
	OGLCOLOR m_BlackKeyColor;
	
	//発音中キー色情報
	OGLCOLOR m_ActiveKeyColor;
	int m_ActiveKeyColorDuration;
	float m_ActiveKeyColorTailRate;
	ActiveKeyColorType m_ActiveKeyColorType;
	
	//キー表示範囲
	int m_KeyDispRangeStart;
	int m_KeyDispRangeEnd;
	
	void _Initialize();
	void _InitKeyType();
	void _InitKeyPos();
	int _LoadConfFile(NSString* pSceneName);
	
};


