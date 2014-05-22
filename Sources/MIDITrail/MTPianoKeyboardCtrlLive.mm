//******************************************************************************
//
// MIDITrail / MTPianoKeyboardCtrlLive
//
// ライブモニタ用ピアノキーボード制御クラス
//
// Copyright (C) 2012-2013 WADA Masashi. All Rights Reserved.
//
//******************************************************************************

#import "YNBaseLib.h"
#import "MTPianoKeyboard.h"
#import "MTPianoKeyboardCtrlLive.h"


//******************************************************************************
// コンストラクタ
//******************************************************************************
MTPianoKeyboardCtrlLive::MTPianoKeyboardCtrlLive(void)
{
	unsigned char chNo = 0;
	
	//キーボードオブジェクト配列初期化
	for (chNo = 0; chNo < SM_MAX_CH_NUM; chNo++) {
		m_pPianoKeyboard[chNo] = NULL;
	}
	
	//ノート情報配列初期化
	_ClearNoteStatus();
	
	m_isEnable = true;
	m_isSingleKeyboard = false;
}

//******************************************************************************
// デストラクタ
//******************************************************************************
MTPianoKeyboardCtrlLive::~MTPianoKeyboardCtrlLive(void)
{
	Release();
}

//******************************************************************************
// 生成処理
//******************************************************************************
int MTPianoKeyboardCtrlLive::Create(
		OGLDevice* pOGLDevice,
		NSString* pSceneName,
		MTNotePitchBend* pNotePitchBend,
		bool isSingleKeyboard
	)
{
	int result = 0;
	
	Release();
	
	//ノートデザインオブジェクト初期化
	result = m_NoteDesign.Initialize(pSceneName, NULL);
	if (result != 0) goto EXIT;
	
	//キーボードデザイン初期化
	result = m_KeyboardDesign.Initialize(pSceneName, NULL);
	if (result != 0) goto EXIT;
	
	//ノート情報配列初期化
	_ClearNoteStatus();
	
	//キーボード生成
	result = _CreateKeyboards(pOGLDevice, pSceneName);
	if (result != 0) goto EXIT;
	
	//ピッチベンド情報
	m_pNotePitchBend = pNotePitchBend;
	
	//シングルキーボードフラグ
	m_isSingleKeyboard = isSingleKeyboard;
	
	//Mach時間
	m_MachTime.Initialize();
	if (result != 0) goto EXIT;
	
EXIT:;
	return result;
}

//******************************************************************************
// ノート情報配列初期化
//******************************************************************************
void MTPianoKeyboardCtrlLive::_ClearNoteStatus()
{
	unsigned long chNo = 0;
	unsigned long noteNo = 0;
	
	//ノート状態リスト初期化
	for (chNo = 0; chNo < SM_MAX_CH_NUM; chNo++) {
		for (noteNo = 0; noteNo < SM_MAX_NOTE_NUM; noteNo++) {
			m_NoteStatus[chNo][noteNo].isActive = false;
			m_NoteStatus[chNo][noteNo].startTime = 0;
			m_NoteStatus[chNo][noteNo].endTime = 0;
			m_NoteStatus[chNo][noteNo].keyDownRate = 0.0f;
		}
	}
	
	return;
}

//******************************************************************************
// キーボード描画オブジェクト生成
//******************************************************************************
int MTPianoKeyboardCtrlLive::_CreateKeyboards(
		OGLDevice* pOGLDevice,
		NSString* pSceneName
	)
{
	int result = 0;
	unsigned char chNo = 0;
	OGLTexture* pTexture = NULL;
	
	for (chNo = 0; chNo < SM_MAX_CH_NUM; chNo++) {
		try {
			m_pPianoKeyboard[chNo] = new MTPianoKeyboard;
		}
		catch (std::bad_alloc) {
			result = YN_SET_ERR(@"Could not allocate memory.", 0, 0);
			goto EXIT;
		}
		
		result = m_pPianoKeyboard[chNo]->Create(pOGLDevice, pSceneName, NULL, pTexture);
		if (result != 0) goto EXIT;
		
		//先頭オブジェクトで作成したテクスチャを再利用する
		pTexture = m_pPianoKeyboard[chNo]->GetTexture();
	}
	
EXIT:;
	return result;
}

//******************************************************************************
// 移動
//******************************************************************************
int MTPianoKeyboardCtrlLive::Transform(
		OGLDevice* pOGLDevice,
		float rollAngle
	)
{
	int result = 0;
	unsigned char portNo = 0;
	unsigned char chNo = 0;
	OGLVECTOR3 moveVector;
	
	//現在発音中ノートの頂点更新
	result = _TransformActiveNotes(pOGLDevice);
	if (result != 0) goto EXIT;
	
	//各キーボードの移動
	for (chNo = 0; chNo < SM_MAX_CH_NUM; chNo++) {
		
		//移動ベクトル：キーボード基準座標
		moveVector = m_KeyboardDesign.GetKeyboardBasePos(portNo, chNo);
		
		//移動ベクトル：ピッチベンドシフトを反映
		moveVector.x += _GetPichBendShiftPosX(portNo, chNo);
		
		//移動ベクトル：再生面に追従する
		//moveVector.y += m_NoteDesign.GetPlayPosX(m_CurTickTime);
		
		//キーボード移動
		result = m_pPianoKeyboard[chNo]->Transform(pOGLDevice, moveVector, rollAngle);
		if (result != 0) goto EXIT;
	}
	
EXIT:;
	return result;
}

//******************************************************************************
// ノートの頂点処理
//******************************************************************************
int MTPianoKeyboardCtrlLive::_TransformActiveNotes(
		OGLDevice* pOGLDevice
	)
{
	int result = 0;
	
	//ノートの状態更新
	result = _UpdateStatusOfActiveNotes(pOGLDevice);
	if (result != 0) goto EXIT;
	
	//ノートの頂点更新
	result = _UpdateVertexOfActiveNotes(pOGLDevice);
	if (result != 0) goto EXIT;
	
EXIT:;
	return result;
}

//******************************************************************************
// ノートの状態更新
//******************************************************************************
int MTPianoKeyboardCtrlLive::_UpdateStatusOfActiveNotes(
		OGLDevice* pOGLDevice
	)
{
	int result = 0;
	unsigned long chNo = 0;
	unsigned long noteNo = 0;
	unsigned long keyUpDuration = 0;
	uint64_t curTime = 0;
	unsigned long targetChNo = 0;
	
	curTime = m_MachTime.GetCurTimeInMsec();
	
	//キー上昇下降時間(msec)
	keyUpDuration = m_KeyboardDesign.GetKeyUpDuration();
	
	//ノート情報を更新する
	for (chNo = 0; chNo < SM_MAX_CH_NUM; chNo++) {
		for (noteNo = 0; noteNo < SM_MAX_NOTE_NUM; noteNo++) {
			//ノートOFF後の状態を更新
			if ((m_NoteStatus[chNo][noteNo].isActive) && (m_NoteStatus[chNo][noteNo].endTime != 0)) {
				//ノートOFFからキーアップまで完了した場合はキー情報をクリアする
				if ((curTime - m_NoteStatus[chNo][noteNo].endTime) > keyUpDuration) {
					m_NoteStatus[chNo][noteNo].isActive = false;
					m_NoteStatus[chNo][noteNo].startTime = 0;
					m_NoteStatus[chNo][noteNo].endTime = 0;
					m_NoteStatus[chNo][noteNo].keyDownRate = 0.0f;
					//シングルキーボードでは複数チャンネルのキー状態を先頭チャンネルに集約する
					targetChNo = chNo;
					if (m_isSingleKeyboard) {
						targetChNo = 0;
					}
					result = m_pPianoKeyboard[targetChNo]->ResetKey((unsigned char)noteNo);
					if (result != 0) goto EXIT;
				}
				//キー押下率を更新
				else {
					m_NoteStatus[chNo][noteNo].keyDownRate
						= 1.0f - ((float)(curTime - m_NoteStatus[chNo][noteNo].endTime) / (float)keyUpDuration);
				}
			}
		}
	}
		
EXIT:;
	return result;
}

//******************************************************************************
// ノートの頂点更新
//******************************************************************************
int MTPianoKeyboardCtrlLive::_UpdateVertexOfActiveNotes(
		OGLDevice* pOGLDevice
	)
{
	int result = 0;
	unsigned long portNo = 0;
	unsigned long chNo = 0;
	unsigned long noteNo = 0;
	unsigned long elapsedTime = 0;
	uint64_t curTime = 0;
	unsigned long targetChNo = 0;
	OGLCOLOR noteColor;
	OGLCOLOR* pActiveKeyColor = NULL;
	
	curTime = m_MachTime.GetCurTimeInMsec();
	
	//キーの状態更新
	for (chNo = 0; chNo < SM_MAX_CH_NUM; chNo++) {
		for (noteNo = 0; noteNo < SM_MAX_NOTE_NUM; noteNo++) {
			//発音中でなければスキップ
			if (!(m_NoteStatus[chNo][noteNo].isActive)) continue;
			
			//発音開始からの経過時間
			elapsedTime = curTime - m_NoteStatus[chNo][noteNo].startTime;
			
			//シングルキーボードでは複数チャンネルのキー状態を先頭チャンネルに集約する
			targetChNo = chNo;
			if (m_isSingleKeyboard) {
				targetChNo = 0;
			}
			
			//ノートの色
			noteColor = m_NoteDesign.GetNoteBoxColor((unsigned char)portNo, (unsigned char)chNo, (unsigned char)noteNo);
			pActiveKeyColor = &noteColor;
			
			//発音対象キーを回転
			result = m_pPianoKeyboard[targetChNo]->PushKey(
								(unsigned char)noteNo,
								m_NoteStatus[chNo][noteNo].keyDownRate,
								elapsedTime,
								pActiveKeyColor
							);
			if (result != 0) goto EXIT;
		}
	}
	
EXIT:;
	return result;
}

//******************************************************************************
// 描画
//******************************************************************************
int MTPianoKeyboardCtrlLive::Draw(
		OGLDevice* pOGLDevice
   )
{
	int result = 0;
	unsigned char chNo = 0;
	unsigned long count = 0;
	unsigned long dispNum = 0;
	
	if (!m_isEnable) goto EXIT;
	
	//キーボード最大表示数
	dispNum = SM_MAX_CH_NUM;
	if (m_KeyboardDesign.GetKeyboardMaxDispNum() < dispNum) {
		dispNum = m_KeyboardDesign.GetKeyboardMaxDispNum();
	}
	
	//キーボードの描画
	for (chNo = 0; chNo < SM_MAX_CH_NUM; chNo++) {
		//キーボード表示数の制限を確認
		count++;
		if (dispNum < count) break;
		
		//キーボード描画
		result = m_pPianoKeyboard[chNo]->Draw(pOGLDevice);
		if (result != 0) goto EXIT;
	}
	
EXIT:;
	return result;
}

//******************************************************************************
// ピッチベンド反映：キーボードシフト
//******************************************************************************
float MTPianoKeyboardCtrlLive::_GetPichBendShiftPosX(
		unsigned char portNo,
		unsigned char chNo
	)
{
	float shift = 0.0f;
	short pitchBendValue = 0;
	unsigned char pitchBendSensitivity = SM_DEFAULT_PITCHBEND_SENSITIVITY;
	
	//チャンネルのピッチベンド情報
	pitchBendValue =       m_pNotePitchBend->GetValue(portNo, chNo);
	pitchBendSensitivity = m_pNotePitchBend->GetSensitivity(portNo, chNo);
	
	//ピッチベンドによるキーボードシフト量
	shift = m_KeyboardDesign.GetPitchBendShift(pitchBendValue, pitchBendSensitivity);
	
	return shift;
}

//******************************************************************************
// 解放
//******************************************************************************
void MTPianoKeyboardCtrlLive::Release()
{
	unsigned char chNo = 0;
	
	for (chNo = 0; chNo < SM_MAX_CH_NUM; chNo++) {
		if (m_pPianoKeyboard[chNo] != NULL) {
			m_pPianoKeyboard[chNo]->Release();
			delete m_pPianoKeyboard[chNo];
			m_pPianoKeyboard[chNo] = NULL;
		}
	}
	
	return;
}

//******************************************************************************
// リセット
//******************************************************************************
void MTPianoKeyboardCtrlLive::Reset()
{
	int result = 0;
	unsigned long chNo = 0;
	unsigned long noteNo = 0;
	
	for (chNo = 0; chNo < SM_MAX_CH_NUM; chNo++) {
		for (noteNo = 0; noteNo < SM_MAX_NOTE_NUM; noteNo++) {
			m_NoteStatus[chNo][noteNo].isActive = false;
			m_NoteStatus[chNo][noteNo].startTime = 0;
			m_NoteStatus[chNo][noteNo].endTime = 0;
			m_NoteStatus[chNo][noteNo].keyDownRate = 0.0f;
			result = m_pPianoKeyboard[chNo]->ResetKey(noteNo);
			if (result != 0) goto EXIT;
		}
	}

EXIT:;
	return;
}

//******************************************************************************
// 表示設定
//******************************************************************************
void MTPianoKeyboardCtrlLive::SetEnable(
		bool isEnable
	)
{
	m_isEnable = isEnable;
}

//******************************************************************************
// ノートON登録
//******************************************************************************
void MTPianoKeyboardCtrlLive::SetNoteOn(
		unsigned char portNo,
		unsigned char chNo,
		unsigned char noteNo,
		unsigned char velocity
	)
{
	uint64_t curTime = 0;
	
	curTime = m_MachTime.GetCurTimeInMsec();
	
	//ノート情報登録
	m_NoteStatus[chNo][noteNo].isActive = true;
	m_NoteStatus[chNo][noteNo].startTime = curTime;
	m_NoteStatus[chNo][noteNo].endTime = 0;
	m_NoteStatus[chNo][noteNo].keyDownRate = 1.0f;
	
	return;
}

//******************************************************************************
// ノートOFF登録
//******************************************************************************
void MTPianoKeyboardCtrlLive::SetNoteOff(
		unsigned char portNo,
		unsigned char chNo,
		unsigned char noteNo
	)
{
	uint64_t curTime = 0;
	
	curTime = m_MachTime.GetCurTimeInMsec();
	
	//ノート情報更新
	m_NoteStatus[chNo][noteNo].endTime = curTime;
	
	return;
}

//******************************************************************************
// 全ノートOFF
//******************************************************************************
void MTPianoKeyboardCtrlLive::AllNoteOff()
{
	unsigned long chNo = 0;
	unsigned long noteNo = 0;
	uint64_t curTime = 0;
	
	curTime = m_MachTime.GetCurTimeInMsec();
	
	//ノートOFFが設定されていないノート情報に終了時刻を設定
	for (chNo = 0; chNo < SM_MAX_CH_NUM; chNo++) {
		for (noteNo = 0; noteNo < SM_MAX_NOTE_NUM; noteNo++) {
			if ((m_NoteStatus[chNo][noteNo].isActive)
				&& (m_NoteStatus[chNo][noteNo].endTime == 0)) {
					m_NoteStatus[chNo][noteNo].endTime = curTime;
			}
		}
	}
				
	return;
}

//******************************************************************************
// 全ノートOFF（チャンネル指定）
//******************************************************************************
void MTPianoKeyboardCtrlLive::AllNoteOffOnCh(
		unsigned char portNo,
		unsigned char chNo
	)
{
	unsigned long noteNo = 0;
	uint64_t curTime = 0;
	
	curTime = m_MachTime.GetCurTimeInMsec();
	
	//指定チャンネルでノートOFFが設定されていないノート情報に終了時刻を設定
	for (noteNo = 0; noteNo < SM_MAX_NOTE_NUM; noteNo++) {
		if ((m_NoteStatus[chNo][noteNo].isActive)
			&& (m_NoteStatus[chNo][noteNo].endTime == 0)) {
				m_NoteStatus[chNo][noteNo].endTime = curTime;
		}
	}
	
	return;
}


