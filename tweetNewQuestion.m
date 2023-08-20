% Copyright (c) 2023 Michio Inoue
% This is a script to check the new questions in Japanese and tweet those
% at https://twitter.com/JPMATLABAnswers
% This is automated using GitHub Actions.

% 1ページ（50投稿分)だけチェック
try
    % トップページの RSS を読み込み（日本語、投稿の新しい順表示）
    xDoc = xmlread('https://jp.mathworks.com/matlabcentral/answers/questions?language=ja&format=atom&sort=asked+desc');
    
    % まず各投稿は <entry></entry> 
    allListitems = xDoc.getElementsByTagName('entry');
    
    % アイテム数だけ配列を確保
    title = strings(allListitems.getLength,1);
    url = strings(allListitems.getLength,1);
    author = strings(allListitems.getLength,1);
    
    % 各アイテムから title, url, author 情報を出します。
    for k = 0:allListitems.getLength-1
        thisListitem = allListitems.item(k);
        
        % Get the title element
        thisList = thisListitem.getElementsByTagName('title');
        thisElement = thisList.item(0);
        % The text is in the first child node.
        title(k+1) = string(thisElement.getFirstChild.getData);
        
        % Get the link element
        thisList = thisListitem.getElementsByTagName('link');
        thisElement = thisList.item(0);
        % The url is one of the attributes
        url(k+1) = string(thisElement.getAttributes.item(0));
        
        % Get the author element
        thisList = thisListitem.getElementsByTagName('author');
        thisElement = thisList.item(0);
        childNodes = thisElement.getChildNodes;
        author(k+1) = string(childNodes.item(1).getFirstChild.getData);
    end
    
    % URL は以下の形になっているので、
    % href="https://www.mathworks.com/matlabcentral/answers/477845-bode-simulink-360"
    url = extractBetween(url,"href=""",""""); % URL 部分だけ取得
    entryID = double(extractBetween(url,"answers/","-")); % 投稿IDを別途確保
    
catch ME
    disp(ME)
    FailAnswersRead = true; % 読み込み失敗
    return;
end

latestID = readmatrix('latestID.txt');

% これまでに検知した最も大きいIDより大きいIDがあれば
% 新規投稿として Tweet
newID = entryID > latestID; % new
idxNew = find(newID);

% 無ければ古い値を使用
if sum(newID) == 0
    LatestID_JP = latestID;
    FlagLatest = 0;
    disp('no new entry');
else
    FlagLatest = true;
    [LatestID_JP,idx] = max(entryID); % latest ID
    % save
    writematrix(LatestID_JP,'latestID.txt')

    % 新しい投稿を Tweet  
    for ii=1:sum(newID)
        thisAuthor = author(idxNew(ii));
        thisTitle = title(idxNew(ii));
        thisURL = url(idxNew(ii));
        % 投稿文：～さんからの質問「質問タイトル」-> URL
        disp([string(ii) + "個目の投稿"]);
        
        if thisAuthor == "MathWorks Support Team"
            status = thisTitle + newline;
            status = status + newline;
            status = status + thisAuthor + " からの新着ヒント" + newline;
            status = status + newline;
            status = status + "#MATLABAnswers" + newline;
            status = status + thisURL + "?s_eid=PSM_29405";
        else
            status = thisTitle + newline;
            status = status + newline;
            status = status + thisAuthor + " さんからの新着質問" + newline;
            status = status + newline;
            status = status + "#MATLABAnswers" + newline;
            status = status + thisURL + "?s_eid=PSM_29405";
        end
        disp(status);
        
        try
            py.tweetJPAnswers.tweetV2(status)
        catch ME
            disp(ME)
            FailTwitterPost = true;
        end
    end
end
