//******************************************************************************
//
// MIDITrail / MTScenePianoRollRain
//
// ピアノロールレインシーン描画クラス
//
// Copyright (C) 2010-2013 WADA Masashi. All Rights Reserved.
//
//******************************************************************************

// MEMO:
// Windows版のソースを移植しているため、座標は左手系(DirectX)で処理している。
// 左手系(DirectX)=>右手系(OpenGL)への変換は LH2RH マクロで実現する。

#import "YNBaseLib.h"
#import "OGLColorUtil.h"
#import "MTConfFile.h"
#import "MTScenePianoRollRain.h"


//******************************************************************************
// コンストラクタ
//******************************************************************************
MTScenePianoRollRain::MTScenePianoRollRain(void)
{
	m_IsEnableLight = true;
	m_IsSingleKeyboard = false;
	m_IsMouseCamMode = false;
	m_IsAutoRollMode = false;
	m_CurTickTime = 0;
	m_IsSkipping = false;
}

//******************************************************************************
// デストラクタ
//******************************************************************************
MTScenePianoRollRain::~MTScenePianoRollRain(void)
{
	Release();
}

//******************************************************************************
// 名称取得
//******************************************************************************
NSString* MTScenePianoRollRain::GetName()
{
	return @"PianoRollRain";
}

//******************************************************************************
// シーン生成
//******************************************************************************
int MTScenePianoRollRain::Create(
		NSView* pView,
		OGLDevice* pOGLDevice,
		SMSeqData* pSeqData
	)
{
	int result = 0;
	
	Release();
	
	if (pOGLDevice == NULL) {
		result = YN_SET_ERR(@"Program error.", 0, 0);
		goto EXIT;
	}
	
	//設定ファイル読み込み
	result = _LoadConf();
	if (result != 0) goto EXIT;
	
	//----------------------------------
	// カメラ
	//----------------------------------
	//カメラ初期化
	result = m_FirstPersonCam.Initialize(pView, GetName(), pSeqData);
	if (result != 0) goto EXIT;
	
	//進行方向
	m_FirstPersonCam.SetProgressDirection(MTFirstPersonCam::DirY);
	
	//デフォルト視点を取得
	GetDefaultViewParam(&m_ViewParamMap);
	
	//視点を設定
	SetViewParam(&m_ViewParamMap);
	
	//----------------------------------
	// ライト
	//----------------------------------
	//ライト初期化
	result = m_DirLight.Initialize();
	if (result != 0) goto EXIT;
	
	//ライト方向
	//  原点を光源としてその方向をベクトルで表現する
	//m_DirLight.SetDirection(D3DXVECTOR3(1.0f, -1.0f, LH2RH(2.0f)));
	m_DirLight.SetDirection(OGLVECTOR3(1.0f, -2.0f, LH2RH(0.5f)));
	
	//ライトのデバイス登録
	result = m_DirLight.SetDevice(pOGLDevice, m_IsEnableLight);
	if (result != 0) goto EXIT;
	
	//----------------------------------
	// 描画オブジェクト
	//----------------------------------
	//ピッチベンド情報初期化
	result = m_NotePitchBend.Initialize();
	if (result != 0) goto EXIT;
	
	//シングルキーボードはピッチベンド無効
	if (m_IsSingleKeyboard) {
		m_NotePitchBend.SetEnable(false);
	}
	else {
		m_NotePitchBend.SetEnable(true);
	}
	
	//ピアノキーボード制御
	result = m_PianoKeyboardCtrl.Create(pOGLDevice, GetName(), pSeqData, &m_NotePitchBend, m_IsSingleKeyboard);
	if (result != 0) goto EXIT;
	
	//ノートレイン
	result = m_NoteRain.Create(pOGLDevice, GetName(), pSeqData, &m_NotePitchBend);
	if (result != 0) goto EXIT;
	
	//ダッシュボード生成
	result = m_Dashboard.Create(pOGLDevice, GetName(), pSeqData, pView);
	if (result != 0) goto EXIT;
	
	//星生成
	result = m_Stars.Create(pOGLDevice, GetName());
	if (result != 0) goto EXIT;
	
	//----------------------------------
	// レンダリングステート
	//----------------------------------
	//画面描画モード
	//裏を向くポリゴンは描画しない（カリング）することにより負荷を下げる
	//  OpenGLとDirectXはポリンゴンの表／裏の方向が逆である
	//  DirectX向けに記載したコードを実行する場合はカリング対象を入れ替える
	glEnable(GL_CULL_FACE);
	if (LH2RH(1) == 1) {
		//OpenGL（右手系）向けコードでのカリング（裏面）
		glCullFace(GL_BACK);
	}
	else {
		//DirectX（左手系）向けコードでのカリング（裏面）
		glCullFace(GL_FRONT);
	}
	
	//Z深度比較：ON
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LEQUAL);  //判定方式をDirectXと同一にする
	
	//ディザリング:ON 高品質描画
	glEnable(GL_DITHER);
	
	//マルチサンプリングアンチエイリアス：有効
	//TODO: 設定必要？
	
	//レンダリングステート設定：通常のアルファ合成
	glDisable(GL_ALPHA_TEST);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	
	//シェーディングモデル
	glShadeModel(GL_SMOOTH);  // or GL_FLAT
	
EXIT:;
	return result;
}

//******************************************************************************
// 変換処理
//******************************************************************************
int MTScenePianoRollRain::Transform(
		OGLDevice* pOGLDevice
	)
{
	int result = 0;
	float rollAngle = 0.0f;
	OGLVECTOR3 camVector;
	
	if (pOGLDevice == NULL) {
		result = YN_SET_ERR(@"Program error.", 0, 0);
		goto EXIT;
	}
	
	//カメラ更新
	result = m_FirstPersonCam.Transform(pOGLDevice, m_isActive);
	if (result != 0) goto EXIT;
	
	//カメラ座標取得
	 m_FirstPersonCam.GetPosition(&camVector);
	
	//回転角度取得
	rollAngle = m_FirstPersonCam.GetManualRollAngle();
	
	//ピアノキーボード更新
	result = m_PianoKeyboardCtrl.Transform(pOGLDevice, rollAngle);
	if (result != 0) goto EXIT;
	
	//ノートレイン更新
	result = m_NoteRain.Transform(pOGLDevice, rollAngle);
	if (result != 0) goto EXIT;
	
	//ダッシュボード更新
	result = m_Dashboard.Transform(pOGLDevice, camVector);
	if (result != 0) goto EXIT;
	
	//星更新
	result = m_Stars.Transform(pOGLDevice, camVector);
	if (result != 0) goto EXIT;
	
EXIT:;
	return result;
}

//******************************************************************************
// 描画
//******************************************************************************
int MTScenePianoRollRain::Draw(
		OGLDevice* pOGLDevice
	)
{
	int result = 0;
	
	if (pOGLDevice == NULL) {
		result = YN_SET_ERR(@"Program error.", 0, 0);
		goto EXIT;
	}
	
	//更新
	result = Transform(pOGLDevice);
	if (result != 0) goto EXIT;
	
	//ピアノキーボード描画
	result = m_PianoKeyboardCtrl.Draw(pOGLDevice);
	if (result != 0) goto EXIT;
	
	//ノートレイン更新
	result = m_NoteRain.Draw(pOGLDevice);
	if (result != 0) goto EXIT;
	
	//星描画
	result = m_Stars.Draw(pOGLDevice);
	if (result != 0) goto EXIT;
	
	//ダッシュボード描画：正射影のため一番最後に描画する
	result = m_Dashboard.Draw(pOGLDevice);
	if (result != 0) goto EXIT;
	
EXIT:;
	return result;
}

//******************************************************************************
// 破棄
//******************************************************************************
void MTScenePianoRollRain::Release()
{
	m_PianoKeyboardCtrl.Release();
	m_NoteRain.Release();
	m_Dashboard.Release();
	m_Stars.Release();
}

//******************************************************************************
// ウィンドウクリックイベント受信
//******************************************************************************
int MTScenePianoRollRain::OnWindowClicked(
		unsigned long button,
		unsigned long wParam,
		unsigned long lParam
	)
{
	int result = 0;
	
	//左ボタン
	if (button == WM_LBUTTONDOWN) {
		//視線方向制御 ON/OFF
		m_IsMouseCamMode = m_IsMouseCamMode ? false : true;
		m_FirstPersonCam.SetMouseCamMode(m_IsMouseCamMode);
	}
	//右ボタン
	else if (button == WM_RBUTTONDOWN) {
		//何もしない
	}
	//中ボタン
	else if (button == WM_MBUTTONDOWN) {
		//自動回転モード ON/OFF
		m_IsAutoRollMode = m_IsAutoRollMode ? false : true;
		m_FirstPersonCam.SetAutoRollMode(m_IsAutoRollMode);
		if (m_IsAutoRollMode) {
			m_FirstPersonCam.SwitchAutoRllDirecton();
		}
	}
	
	return result;
}

//******************************************************************************
//マウスホイールイベント受信
//******************************************************************************
int MTScenePianoRollRain::OnScrollWheel(
		float deltaWheelX,
		float deltaWheelY,
		float deltaWheelZ
	)
{
	m_FirstPersonCam.OnScrollWheel(deltaWheelX, deltaWheelY, deltaWheelZ);
	return 0;
}

//******************************************************************************
// 演奏開始イベント受信
//******************************************************************************
int MTScenePianoRollRain::OnPlayStart()
{
	int result = 0;
	
	_Reset();
	
	return result;
}

//******************************************************************************
// 演奏終了イベント受信
//******************************************************************************
int MTScenePianoRollRain::OnPlayEnd()
{
	int result = 0;
	
	return result;
}

//******************************************************************************
// シーケンサメッセージ受信
//******************************************************************************
int MTScenePianoRollRain::OnRecvSequencerMsg(
		unsigned long wParam,
		unsigned long lParam
	)
{
	int result = 0;
	SMMsgParser parser;
	
	parser.Parse(wParam, lParam);
	
	//演奏状態通知
	if (parser.GetMsg() == SMMsgParser::MsgPlayStatus) {
		if (parser.GetPlayStatus() == SMMsgParser::StatusStop) {
			//停止（終了）
		}
		else if (parser.GetPlayStatus() == SMMsgParser::StatusPlay) {
			//演奏
		}
		else if (parser.GetPlayStatus() == SMMsgParser::StatusPause) {
			//一時停止
		}
	}
	//演奏チックタイム通知
	else if (parser.GetMsg() == SMMsgParser::MsgPlayTime) {
		m_Dashboard.SetPlayTimeSec(parser.GetPlayTimeSec());
		m_PianoKeyboardCtrl.SetPlayTimeMSec(parser.GetPlayTimeMSec());
		m_NoteRain.SetCurTickTime(parser.GetPlayTickTime());
		m_CurTickTime = parser.GetPlayTickTime();
		
		//ノートを移動せずにカメラとキーボードを移動させる場合
		//m_FirstPersonCam.SetCurTickTime(parser.GetPlayTickTime());
		//m_PianoKeyboardCtrl.SetCurTickTime(parser.GetPlayTickTime());
	}
	//テンポ変更通知
	else if (parser.GetMsg() == SMMsgParser::MsgTempo) {
		m_Dashboard.SetTempoBPM(parser.GetTempoBPM());
	}
	//小節番号通知
	else if (parser.GetMsg() == SMMsgParser::MsgBar) {
		m_Dashboard.SetBarNo(parser.GetBarNo());
	}
	//拍子記号変更通知
	else if (parser.GetMsg() == SMMsgParser::MsgBeat) {
		m_Dashboard.SetBeat(parser.GetBeatNumerator(), parser.GetBeatDenominator());
	}
	//ノートOFF通知
	else if (parser.GetMsg() == SMMsgParser::MsgNoteOff) {
	}
	//ノートON通知
	else if (parser.GetMsg() == SMMsgParser::MsgNoteOn) {
		m_Dashboard.SetNoteOn();
	}
	//ピッチベンド通知
	else if (parser.GetMsg() == SMMsgParser::MsgPitchBend) {
		m_NotePitchBend.SetPitchBend(
							parser.GetPortNo(),
							parser.GetChNo(),
							parser.GetPitchBendValue(),
							parser.GetPitchBendSensitivity()
						);
	}
	//スキップ開始通知
	else if (parser.GetMsg() == SMMsgParser::MsgSkipStart) {
		if (parser.GetSkipStartDirection() == SMMsgParser::SkipBack) {
			m_NotePitchBend.Reset();
		}
		m_PianoKeyboardCtrl.Reset();
		m_PianoKeyboardCtrl.SetSkipStatus(true);
		m_NoteRain.Reset();
		m_NoteRain.SetSkipStatus(true);
		m_NoteRain.SetCurTickTime(m_CurTickTime);
		m_IsSkipping = true;
	}
	//スキップ終了通知
	else if (parser.GetMsg() == SMMsgParser::MsgSkipEnd) {
		m_Dashboard.SetNotesCount(parser.GetSkipEndNotesCount());
		m_PianoKeyboardCtrl.SetSkipStatus(false);
		m_NoteRain.SetSkipStatus(false);
		m_IsSkipping = false;
	}
	
//EXIT:;
	return result;
}

//******************************************************************************
// 巻き戻し
//******************************************************************************
int MTScenePianoRollRain::Rewind()
{
	int result = 0;
	
	_Reset();
	
	//視点を設定
	SetViewParam(&m_ViewParamMap);
	
	return result;
}

//******************************************************************************
// リセット
//******************************************************************************
void MTScenePianoRollRain::_Reset()
{
	m_Dashboard.Reset();
	m_FirstPersonCam.Reset();
	m_PianoKeyboardCtrl.Reset();
	m_NoteRain.Reset();
	m_NotePitchBend.Reset();
	m_CurTickTime = 0;
}

//******************************************************************************
// デフォルト視点取得
//******************************************************************************
void MTScenePianoRollRain::GetDefaultViewParam(
		MTViewParamMap* pParamMap
	)
{
	OGLVECTOR3 viewPointVector;
	float phi, theta = 0.0f;
	
	//視点情報作成
	viewPointVector.x = 0.0f;
	viewPointVector.y = 0.0f;
	viewPointVector.z = LH2RH(-(1.5f * 16.0f / 2.0f) - 10.0f);
	phi   = LH2RH(90.0f);	//+Z軸方向
	theta = 90.0f;	//+Z軸方向
	
	pParamMap->clear();
	pParamMap->insert(MTViewParamMapPair("X", viewPointVector.x));
	pParamMap->insert(MTViewParamMapPair("Y", viewPointVector.y));
	pParamMap->insert(MTViewParamMapPair("Z", viewPointVector.z));
	pParamMap->insert(MTViewParamMapPair("Phi", phi));
	pParamMap->insert(MTViewParamMapPair("Theta", theta));
	pParamMap->insert(MTViewParamMapPair("ManualRollAngle", 0.0f));
	pParamMap->insert(MTViewParamMapPair("AutoRollVelocity", 0.0f));
	
	return;
}

//******************************************************************************
// 視点取得
//******************************************************************************
void MTScenePianoRollRain::GetViewParam(
		MTViewParamMap* pParamMap
	)
{
	OGLVECTOR3 viewPointVector;
	float phi, theta = 0.0f;
	float manualRollAngle = 0.0f;
	float autoRollVelocity = 0.0f;
	
	//カメラの位置と方向を取得
	m_FirstPersonCam.GetPosition(&viewPointVector);
	m_FirstPersonCam.GetDirection(&phi, &theta);
	
	//ノートを移動せずにカメラとキーボードを移動させる場合
	//再生面に対する視点であるためY軸方向は再生位置を考慮する
	//viewPointVector.y -= m_NoteRain.GetPos();
	
	//回転角度を取得
	manualRollAngle = m_FirstPersonCam.GetManualRollAngle();
	if (m_IsAutoRollMode) {
		autoRollVelocity = m_FirstPersonCam.GetAutoRollVelocity();
	}
	
	pParamMap->clear();
	pParamMap->insert(MTViewParamMapPair("X", viewPointVector.x));
	pParamMap->insert(MTViewParamMapPair("Y", viewPointVector.y));
	pParamMap->insert(MTViewParamMapPair("Z", viewPointVector.z));
	pParamMap->insert(MTViewParamMapPair("Phi", phi));
	pParamMap->insert(MTViewParamMapPair("Theta", theta));
	pParamMap->insert(MTViewParamMapPair("ManualRollAngle", manualRollAngle));
	pParamMap->insert(MTViewParamMapPair("AutoRollVelocity", autoRollVelocity));
	
	return;
}

//******************************************************************************
// 視点登録
//******************************************************************************
void MTScenePianoRollRain::SetViewParam(
		MTViewParamMap* pParamMap
	)
{
	OGLVECTOR3 viewPointVector = OGLVECTOR3(0.0f, 0.0f, 0.0f);
	float phi, theta = 0.0f;
	float manualRollAngle = 0.0f;
	float autoRollVelocity = 0.0f;
	MTViewParamMap::iterator itr;
	
	itr = pParamMap->find("X");
	if (itr != pParamMap->end()) {
		viewPointVector.x = itr->second;
	}
	itr = pParamMap->find("Y");
	if (itr != pParamMap->end()) {
		viewPointVector.y = itr->second;
	}
	itr = pParamMap->find("Z");
	if (itr != pParamMap->end()) {
		viewPointVector.z = itr->second;
	}
	itr = pParamMap->find("Phi");
	if (itr != pParamMap->end()) {
		phi = itr->second;
	}
	itr = pParamMap->find("Theta");
	if (itr != pParamMap->end()) {
		theta = itr->second;
	}
	itr = pParamMap->find("ManualRollAngle");
	if (itr != pParamMap->end()) {
		manualRollAngle = itr->second;
	}
	itr = pParamMap->find("AutoRollVelocity");
	if (itr != pParamMap->end()) {
		autoRollVelocity = itr->second;
	}
	
	//ノートを移動せずにカメラとキーボードを移動させる場合
	//再生面に対する視点であるためY軸方向は再生位置を考慮する
	//viewPointVector.y += m_NoteRain.GetPos();
	
	//カメラの位置と方向を設定
	m_FirstPersonCam.SetPosition(viewPointVector);
	m_FirstPersonCam.SetDirection(phi, theta);
	
	//手動回転角度を設定
	m_FirstPersonCam.SetManualRollAngle(manualRollAngle);
	
	//自動回転速度を設定
	m_IsAutoRollMode = false;
	if (autoRollVelocity != 0.0f) {
		m_IsAutoRollMode = true;
		m_FirstPersonCam.SetAutoRollVelocity(autoRollVelocity);
	}
	m_FirstPersonCam.SetAutoRollMode(m_IsAutoRollMode);
	
	//パラメータの保存
	if (pParamMap != (&m_ViewParamMap)) {
		m_ViewParamMap.clear();
		for (itr = pParamMap->begin(); itr != pParamMap->end(); itr++) {
			m_ViewParamMap.insert(MTViewParamMapPair(itr->first, itr->second));
		}
	}
	
	return;
}

//******************************************************************************
// 視点リセット
//******************************************************************************
void MTScenePianoRollRain::ResetViewpoint()
{
	MTViewParamMap paramMap;
	
	//デフォルト視点を取得
	GetDefaultViewParam(&paramMap);
	
	//視点登録
	SetViewParam(&paramMap);
}

//******************************************************************************
// 表示効果設定
//******************************************************************************
void MTScenePianoRollRain::SetEffect(
		MTScene::EffectType type,
		bool isEnable
	)
{
	switch (type) {
		case EffectPianoKeyboard:
			m_PianoKeyboardCtrl.SetEnable(isEnable);
			break;
		case EffectRipple:
			break;
		case EffectPitchBend:
			if (!m_IsSingleKeyboard) {
				m_NotePitchBend.SetEnable(isEnable);
			}
			break;
		case EffectStars:
			m_Stars.SetEnable(isEnable);
			break;
		case EffectCounter:
			m_Dashboard.SetEnable(isEnable);
			break;
		case EffectFileName:
			m_Dashboard.SetEnableFileName(isEnable);
			break;
		default:
			break;
	}
	
	return;
}

//******************************************************************************
// 演奏速度設定
//******************************************************************************
void MTScenePianoRollRain::SetPlaySpeedRatio(
		unsigned long ratio
	)
{
	m_Dashboard.SetPlaySpeedRatio(ratio);
}

//******************************************************************************
// 設定ファイル読み込み
//******************************************************************************
int MTScenePianoRollRain::_LoadConf()
{
	int result = 0;
	NSString* pHexColor = nil;
	MTConfFile confFile;
	
	result = confFile.Initialize(GetName());
	if (result != 0) goto EXIT;
	
	result = confFile.SetCurSection(@"Color");
	if (result != 0) goto EXIT;
	
	result = confFile.GetStr(@"BackGroundRGBA", &pHexColor, @"000000FF");
	if (result != 0) goto EXIT;
	
	SetBGColor(OGLColorUtil::MakeColorFromHexRGBA(pHexColor));
	
EXIT:;
	return result;
}

