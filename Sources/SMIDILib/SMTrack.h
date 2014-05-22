//******************************************************************************
//
// Simple MIDI Library / SMTrack
//
// トラッククラス
//
// Copyright (C) 2010 WADA Masashi. All Rights Reserved.
//
//******************************************************************************

// MEMO:
// SysEXイベントとメタイベントは可変長サイズのため、単純リストクラスを
// そのまま利用できない。しかしこれらのイベントは、必ず4byteに収まるMIDI
// イベントに比べて圧倒的に少ないので、個々にnewされることを容認し、
// mapで管理する。
//
// TODO:
// SMEventクラスにデルタタイムとポート番号を持たせるべき。
// イベント／デルタタイム／ポート番号を分離しているため、
// SMTrackクラス利用者の処理が煩雑になっている。

#import "SMSimpleList.h"
#import "SMEvent.h"
#import "SMNoteList.h"
#import <map>

#pragma warning(disable:4251)


//******************************************************************************
// トラッククラス
//******************************************************************************
class SMTrack
{
public:
	
	//コンストラクタ／デストラクタ
	SMTrack(void);
	virtual ~SMTrack(void);
	
	//クリア
	void Clear();
	
	//データセット登録
	int AddDataSet(unsigned long deltaTime, SMEvent* pEvent, unsigned char portNo);
	
	//データセット取得
	int GetDataSet(unsigned long index, unsigned long* pDeltaTime, SMEvent* pEvent, unsigned char* pPortNo);
	
	//データセット数取得
	unsigned long GetSize();
	
	//ノートリスト取得：startTime, endTime はチックタイム
	int GetNoteList(SMNoteList* pNoteList);
	
	//ノートリスト取得：startTime, endTime はリアルタイム(msec)
	int GetNoteListWithRealTime(SMNoteList* pNoteList, unsigned long timeDivision);
	
	//コピー
	int CopyFrom(SMTrack* pSrcTrack);
	
private:
	
	//イベントデータ
	typedef struct {
		SMEvent::EventType type;
		unsigned char status;
		unsigned char meta;
		unsigned long size;
		unsigned char data[4];
	} SMEventData;
	
	//データセット
	typedef struct {
		unsigned long deltaTime;
		SMEventData eventData;
		unsigned char portNo;
	} SMDataSet;
	
	//拡張データマップ：インデックス→データ位置
	typedef std::map<unsigned long, unsigned char*> SMExDataMap;
	typedef std::pair<unsigned long, unsigned char*> SMExDataMapPair;
	
	//ノート情報マップ：ノート特定キー→ノートリストインデックス
	typedef std::map<unsigned long, unsigned long> SMNoteMap;
	typedef std::pair<unsigned long, unsigned long> SMNoteMapPair;
	
private:
	
	SMSimpleList m_List;
	SMExDataMap m_ExDataMap;
	
	unsigned long _GetNoteKey(unsigned char portNo, unsigned char chNo, unsigned char noteNo);
	int _GetNoteList(SMNoteList* pNoteList, unsigned long timeDivision);
	double _ConvTick2TimeMsec(unsigned long tickTime, unsigned long tempo, unsigned long timeDivision);
	
	//代入とコピーコンストラクタの禁止
	void operator=(const SMTrack&);
	SMTrack(const SMTrack&);

};

#pragma warning(default:4251)


