//******************************************************************************
//
// MIDITrail / MTGridBoxLive
//
// ライブモニタ用グリッドボックス描画クラス
//
// Copyright (C) 2012-2013 WADA Masashi. All Rights Reserved.
//
//******************************************************************************

// MEMO:
// Windows版のソースを移植しているため、座標は左手系(DirectX)で処理している。
// 左手系(DirectX)=>右手系(OpenGL)への変換は LH2RH マクロで実現する。

#import "YNBaseLib.h"
#import "MTGridBoxLive.h"


//******************************************************************************
// コンストラクタ
//******************************************************************************
MTGridBoxLive::MTGridBoxLive(void)
{
	m_isVisible = true;
}

//******************************************************************************
// デストラクタ
//******************************************************************************
MTGridBoxLive::~MTGridBoxLive(void)
{
	Release();
}

//******************************************************************************
// グリッド生成
//******************************************************************************
int MTGridBoxLive::Create(
		OGLDevice* pOGLDevice,
		NSString* pSceneName
   )
{
	int result = 0;
	SMBarList barList;
	unsigned long vertexNum = 0;
	unsigned long indexNum = 0;
	MTGRIDBOXLIVE_VERTEX* pVertex = NULL;
	unsigned long* pIndex = NULL;
	OGLMATERIAL material;
	OGLCOLOR lineColor;
	
	Release();
	
	if (pOGLDevice == NULL) {
		result = YN_SET_ERR(@"Program error.", 0, 0);
		goto EXIT;
	}
	
	//ノートデザインオブジェクト初期化
	result = m_NoteDesign.Initialize(pSceneName, NULL);
	if (result != 0) goto EXIT;
	
	//プリミティブ初期化
	result = m_Primitive.Initialize(
					sizeof(MTGRIDBOXLIVE_VERTEX),	//頂点サイズ
					_GetFVFFormat(),			//頂点FVFフォーマット
					GL_LINES					//プリミティブ種別
				);
	if (result != 0) goto EXIT;
	
	//頂点バッファ生成：1直方体8頂点
	vertexNum = 8;
	result = m_Primitive.CreateVertexBuffer(pOGLDevice, vertexNum);
	if (result != 0) goto EXIT;
	
	//インデックスバッファ生成：(1直方体12辺 * 2頂点)
	indexNum = 24;
	result = m_Primitive.CreateIndexBuffer(pOGLDevice, indexNum);
	if (result != 0) goto EXIT;
	
	//バッファのロック
	result = m_Primitive.LockVertex((void**)&pVertex);
	if (result != 0) goto EXIT;
	result = m_Primitive.LockIndex(&pIndex);
	if (result != 0) goto EXIT;
	
	//グリッドボックスの頂点とインデックスを生成
	result = _CreateVertexOfGrid(
					pVertex,		//頂点バッファ書き込み位置
					pIndex			//インデックスバッファ書き込み位置
				);
	if (result != 0) goto EXIT;
	
	//バッファのロック解除
	result = m_Primitive.UnlockVertex();
	if (result != 0) goto EXIT;
	result = m_Primitive.UnlockIndex();
	if (result != 0) goto EXIT;
	
	//マテリアル作成
	_MakeMaterial(&material);
	m_Primitive.SetMaterial(material);
	
	//グリッドの色を確認
	lineColor = m_NoteDesign.GetGridLineColor();
	if (((GLuint)lineColor & 0xFF000000) == 0) {
		//透明なら描画しない
		m_isVisible = false;
	}

EXIT:;
	return result;
}

//******************************************************************************
// 移動
//******************************************************************************
int MTGridBoxLive::Transform(
		OGLDevice* pOGLDevice,
		float rollAngle
	)
{
	int result = 0;
	OGLVECTOR3 moveVector;
	OGLTransMatrix transMatrix;
	
	//回転
	transMatrix.RegistRotationX(rollAngle);
	
	//移動
	moveVector = m_NoteDesign.GetWorldMoveVector();
	transMatrix.RegistTranslation(moveVector.x, moveVector.y, moveVector.z);
	
	//左手系(DirectX)=>右手系(OpenGL)の変換
	transMatrix.RegistScale(1.0f, 1.0f, LH2RH(1.0f));
	
	//変換行列設定
	m_Primitive.Transform(&transMatrix);
	
	return result;
}

//******************************************************************************
// 描画
//******************************************************************************
int MTGridBoxLive::Draw(
		OGLDevice* pOGLDevice
   )
{
	int result = 0;
	
	if (m_isVisible) {
		result = m_Primitive.Draw(pOGLDevice);
		if (result != 0) goto EXIT;
	}
	
EXIT:;
	return result;
}

//******************************************************************************
// 解放
//******************************************************************************
void MTGridBoxLive::Release()
{
	m_Primitive.Release();
}

//******************************************************************************
// グリッド頂点生成
//******************************************************************************
int MTGridBoxLive::_CreateVertexOfGrid(
		MTGRIDBOXLIVE_VERTEX* pVertex,
		unsigned long* pIndex
	)
{
	int result = 0;
	unsigned long i = 0;
	OGLVECTOR3 vectorStart[4];
	OGLVECTOR3 vectorEnd[4];
	unsigned long elapsedTime = 0;
	unsigned char portNo = 0;
	
	//     +   1+----+3   +
	//    /|   / 上 /    /|gridH    y x
	//   + | 0+----+2   + |右       |/
	// 左| +   7+----+5 | +      z--+0
	//   |/    / 下 /   |/
	//   +   6+----+4   + ← 4 が原点(0,0,0)
	//        gridW
	
	//グリッドボックス頂点座標取得
	elapsedTime = 0;
	m_NoteDesign.GetGridBoxVirtexPosLive(
			elapsedTime,
			portNo,
			&(vectorStart[0]),
			&(vectorStart[1]),
			&(vectorStart[2]),
			&(vectorStart[3])
		);
	elapsedTime = m_NoteDesign.GetLiveMonitorDisplayDuration();
	m_NoteDesign.GetGridBoxVirtexPosLive(
			elapsedTime,
			portNo,
			&(vectorEnd[0]),
			&(vectorEnd[1]),
			&(vectorEnd[2]),
			&(vectorEnd[3])
		);
	
	//頂点座標・・・法線が異なるので頂点を8個に集約できない
	//上の面
	pVertex[0].p = vectorStart[0];
	pVertex[1].p = vectorEnd[0];
	pVertex[2].p = vectorStart[1];
	pVertex[3].p = vectorEnd[1];
	//下の面
	pVertex[4].p = vectorStart[3];
	pVertex[5].p = vectorEnd[3];
	pVertex[6].p = vectorStart[2];
	pVertex[7].p = vectorEnd[2];
	
	//各頂点の法線
	for (i = 0; i < 8; i++) {
		pVertex[i].n = OGLVECTOR3(0.0f, 0.0f, -1.0f);
	}
	
	//各頂点のディフューズ色
	for (i = 0; i < 8; i++) {
		pVertex[i].c = m_NoteDesign.GetGridLineColor();
	}
	
	//インデックス：DrawIndexdPrimitive呼び出しが1回で済むようにLINELISTとする
	unsigned long index[24] = {
		0, 1,  // 1 上面の辺
		1, 3,  // 2 ：
		3, 2,  // 3 ：
		2, 0,  // 4 ：
		6, 7,  // 5 下面の辺
		7, 5,  // 6 ：
		5, 4,  // 7 ：
		4, 6,  // 8 ：
		0, 6,  // 9 縦の線
		1, 7,  //10 ：
		3, 5,  //11 ：
		2, 4   //12 ：
	};
	for (i = 0; i < 24; i++) {
		pIndex[i] = index[i];
	}
	
	return result;
}

//******************************************************************************
// マテリアル作成
//******************************************************************************
void MTGridBoxLive::_MakeMaterial(
		OGLMATERIAL* pMaterial
	)
{
	memset(pMaterial, 0, sizeof(OGLMATERIAL));
	
	//拡散光
	pMaterial->Diffuse.r = 1.0f;
	pMaterial->Diffuse.g = 1.0f;
	pMaterial->Diffuse.b = 1.0f;
	pMaterial->Diffuse.a = 1.0f;
	//環境光：影の色
	pMaterial->Ambient.r = 0.5f;
	pMaterial->Ambient.g = 0.5f;
	pMaterial->Ambient.b = 0.5f;
	pMaterial->Ambient.a = 1.0f;
	//鏡面反射光
	pMaterial->Specular.r = 0.2f;
	pMaterial->Specular.g = 0.2f;
	pMaterial->Specular.b = 0.2f;
	pMaterial->Specular.a = 1.0f;
	//鏡面反射光の鮮明度
	pMaterial->Power = 10.0f;
	//発光色
	pMaterial->Emissive.r = 0.0f;
	pMaterial->Emissive.g = 0.0f;
	pMaterial->Emissive.b = 0.0f;
	pMaterial->Emissive.a = 0.0f;
}


