# Who is the Ground Truth
- 眠気吹き飛ぶGT対決。あなたの指と直感でAIのGround Truthを叩きのめせ。
- Pixabay探索・アルバムの刺客・ラベルおみくじの3ステージ。手持ちの一枚でAIを惑わせよう。
- Core MLローカル推論で即ジャッジ、写真もその場で完結。スピード勝負で言い訳の余地なし。

## これなに
- Pixabay検索、フォトライブラリ、ランダムお題で画像を用意し、AIの推論とあなたの答えを即判定する遊びアプリ。
- 3モードを好きな順で遊べるワン画面構成。迷わず「画像→答え→判定」。
- すべて端末内のCore MLモデルでラベル推論。通信はPixabay検索時のみ。

<img width="200" alt="Simulator Screenshot - iPhone 16_ios26 - 2025-12-03 at 01 36 45" src="https://github.com/user-attachments/assets/86216312-9ff6-4d65-b7d8-0c7b5cad177c" />
<img width="200" alt="Simulator Screenshot - iPhone 16_ios26 - 2025-12-03 at 01 57 27" src="https://github.com/user-attachments/assets/adcfb386-86ae-45b3-bec0-6843548d5df5" />
<img width="200" alt="Simulator Screenshot - iPhone 16_ios26 - 2025-12-03 at 01 55 56" src="https://github.com/user-attachments/assets/178399a0-8aae-4ec9-90eb-805911e6406c" />
<img width="200" alt="Simulator Screenshot - iPhone 16_ios26 - 2025-12-03 at 01 54 40" src="https://github.com/user-attachments/assets/21adf5a1-9186-4897-ab3d-c79eb5f5a100" />


## 遊び方（ざっくり3ステップ）
1. アプリを開いてモードを選ぶ（Stock Safari / Album Boss / Label Roulette）。
2. 画像を用意する（Pixabay検索、アルバムから選択、またはおみくじで自動取得）。
3. AIの予測を見つつ、自分の答えを入力して「判定」。勝敗とネタバレが即表示。

## モード紹介
- Stock Safari: Pixabayで好きなワードを検索して即勝負。
- Album Boss: カメラロールの秘蔵写真でAIに一撃。
- Label Roulette: ランダムお題。何が出るかは判定まで秘密。


## プライバシーポリシー
- 画像認識は端末内のCore MLモデルで処理し、選んだ写真や判定結果を外部送信しません。
- Pixabay検索では、入力したキーワードをPixabay APIへ送信して画像を取得します（Pixabayの利用規約に準拠）。
- カメラロールから選んだ写真は端末内のみで利用し、サーバーへアップロードしません。
- クイズ履歴は端末内（UserDefaults）に保存され、アンインストール時に消去されます。サーバー側での保存や共有は行いません。
- 広告・分析用のトラッキングは実装していません。
