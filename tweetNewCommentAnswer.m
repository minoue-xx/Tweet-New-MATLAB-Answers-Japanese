% Copyright (c) 2023 Michio Inoue
% This is a script to check the new comments/answers to questions in Japanese and tweet those
% at https://twitter.com/JPMATLABAnswers
% This is automated using GitHub Actions.
 
try
    xDoc = xmlread('https://jp.mathworks.com/matlabcentral/answers/questions?language=ja&format=atom&sort=updated+desc&status=answered');
    % まず各投稿は <entry></entry>
    allListitems = xDoc.getElementsByTagName('entry');
    
    % アイテム数だけ配列を確保
    title = strings(allListitems.getLength,1);
    url = strings(allListitems.getLength,1);
    author = strings(allListitems.getLength,1);
    updated = strings(allListitems.getLength,1);
    
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
        
        % Get the
        %         <updated>2020-04-18T16:40:12Z</updated>
        thisList = thisListitem.getElementsByTagName('updated');
        thisElement = thisList.item(0);
        updated(k+1) = string(thisElement.getFirstChild.getData);
        
    end
    updated_at = datetime(updated,'InputFormat', "uuuu-MM-dd'T'HH:mm:ss'Z",'TimeZone','UTC');
    updated_at.Format = 'uuuu-MM-dd HH:mm:ss';
    
    % URL は以下の形になっているので、
    % href="https://www.mathworks.com/matlabcentral/answers/477845-bode-simulink-360"
    url = extractBetween(url,"href=""",""""); % URL 部分だけ取得
    entryID = double(extractBetween(url,"answers/","-")); % 投稿IDを別途確保
    
    item_list = timetable(title, url, author, 'RowTimes', updated_at,...
        'VariableNames',{'titles', 'urls', 'authors'})
    
catch ME
    disp(ME)
    FailAnswersRead = true; % 読み込み失敗
    return;
end

%%
% 新着かどうかのチェック
% このスクリプトは 2時間に1回実行する設定にします。(GitHub Action)
% なので、、現時刻から2時間以内に投稿されていればそれは新着記事とします。
interval = duration(2,0,0);
tnow = datetime;
% ThingSpeak が動いているところでは TimeZone が UTC であるところに注意
tnow.TimeZone = 'UTC';

trange = timerange(tnow-interval,tnow); % interval 以内の投稿だけを抽出
newitem_list = item_list(trange,:)
%%

tweetFlag = true;
% 新着の数だけ呟きます（無ければ呟かない）
for ii=1:height(newitem_list)
    
    thisAuthor = newitem_list.authors(ii);
    if thisAuthor == "MathWorks Support Team"
        continue;
    else
        
        % 投稿文
        status = newitem_list.titles(ii) + newline;
        status = status + newline;
        status = status + "コメント/回答が付いています。" + newline;
        status = status + newline;
        status = status + "#MATLABAnswers" + newline;
        status = status + newitem_list.urls(ii)  + "?s_eid=PSM_29405";
        
        disp(status);
    end
    
    if tweetFlag
        try
            py.tweetJPAnswers.tweetV2(status)
        catch ME
            disp(ME)
        end
    end
end