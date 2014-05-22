//******************************************************************************
//
// Simple MIDI Library / SMPortList
//
// ポートリストクラス
//
// Copyright (C) 2010 WADA Masashi. All Rights Reserved.
//
//******************************************************************************

#import "SMSimpleList.h"


//******************************************************************************
// ポートリストクラス
//******************************************************************************
class SMPortList
{
public:
	
	//コンストラクタ／デストラクタ
	SMPortList(void);
	virtual ~SMPortList(void);
	
	//クリア
	void Clear();
	
	//ポート登録
	int AddPort(unsigned char portNo);
	
	//ポート取得
	int GetPort(unsigned long index, unsigned char* pPortNo);
	
	//ポート数取得
	unsigned long GetSize();
	
	//コピー
	int CopyFrom(SMPortList* pSrcList);
	
private:
	
	SMSimpleList m_List;
	
	//代入とコピーコンストラクタの禁止
	void operator=(const SMPortList&);
	SMPortList(const SMPortList&);

};


