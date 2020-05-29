import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

const List<String> _markdownData = [
  """
## Get User Profile:

- Endpoint: `/`
- Method: GET
- Params: [ "query_type" = "Profile", "online_id" = <user_online_id string> ]
- Example: __`https://<Domain>?query_type=Profile&online_id=Hakoom`__

""",
  """
## Get Trophy Titles:

- Endpoint: `/`
- Method: GET
- Params: [ "query_type" = "Titles", "online_id" = <user_online_id string>, "offset" = <integer> ]
- Example: __`https://<Domain>?query_type=Titles&online_id=Hakoom&offset=0`__

""",
  """
## Get Trophy Set:

- Endpoint: `/`
- Method: GET
- Params: [ "query_type" = "TrophySet", "online_id" = <user_online_id string>, "np_communication_id" = <PSN game id string> ]
- Example: __`https://<Domain>?query_type=TrophySet&online_id=Hakoom&np_communication_id=NPWR10788_00`__

""",
  """
## Send PSN Message:

- Endpoint: `/message`
- Method: POST
- Multipart/form-data body:
        
        - key: "online_id", value: <psn_online_id_string>, content_type: "text/plain"
        - key: "message", value: <message_string>, content_type: "text/plain"
        - key: "picture", value: <picture_file_less_than_1mb>, content_type: "image/png"
        - *. "picture" key is optional and can be ignored if the message is text only

- Response JSON body:

        {
	        "status": <status code>,
            "error": Option<error string>
        }    

""",
  """
## Get PSN Store item:

- Endpoint: `/`
- Method: GET
- Params: [ "query_type" = "Store", "language", "region", "age", "name" ]
- Example: __`https://<Domain>?query_type=Store&language=en&region=us&age=21&name=ace%20combat`__

""",
  """
## NpssoRequest:
- Endpoint: `/admin`
- Method: POST
- Header: [ "Authorization" = "Bearer <`BEARER_TOKEN` in `.env` file>" ]
- JSON body:
  
       {
	        "accounts": [
    	        ...,
                {
                    "email": <psn_account_email_address>,
                    "password": <psn_account_password>
    	        }
	        ]
        }

- Response JSON body:
  
        {
	        "status": <status code>,
            "solver_id": <uuid v4 string>,
        }

## RetrieveNpsso:
*. `NpssoRequest` can take a long time to finish. You may need multiple request to see the final result.

- Endpoint: `/admin`
- Method: GET
- Header: [ "Authorization" = "Bearer <`BEARER_TOKEN` in `.env` file>" ]
- Params: [ "query_type" = "SolverId", solver_id = <`solver_id` from `NpssoRequest`'s Response JSON body> ]
- Example: `https://<Domain>/admin?query_type=SolverId&solver_id=f71d553b-b9ba-46ce-a91f-e1a4c1448c1d`
- Response JSON body:

        {
            "status": <status code>,
            "npsso": Option<[
                ...,
                {
                    "email": <psn_account_email_address>,
                    "npsso": Option<npsso string>,
                    "expires_at": Option<utc time string>,
                    "error": Option<error string>,
                }
            ]>
            "error": Option<error string>
        }
        *. Option<x> means the field could be null. This is to minimize the case of undefined

## SetNpsso:
- Endpoint: `/admin/npsso`
- Method: POST
- Header: [ "Authorization" = "Bearer <`BEARER_TOKEN` in `.env` file>" ]
- JSON body:
  
        {
            "psn_inners": [
                ...,
                {
                    "email": <psn_account_email_address>,
                    "online_id": <psn_account_online_id>,
                    "npsso": <npsso string>,
                    "region": <region string>,
                    "language": <languange string>,
                }
            ]
        }
- Response JSON body:

        {
            "status": <status code>,
            "psn_running": <boolean while true means the psn api server starts to run>,
            "failures": Option<[
                ...,
                {
                    email: <psn_account_email_address>,
                    npsso: <npsso string>,
                    error: <error string>,
                }
            ]>,
        }
        *. Option<x> means the field could be null. This is to minimize the case of undefined

""",
];

class MarkDownReqWidget extends StatelessWidget {
  final int index;

  MarkDownReqWidget({this.index});

  @override
  Widget build(BuildContext context) {
    return MarkDownWidget(data: _markdownData[index]);
  }
}

class MarkDownResponseWidget extends StatelessWidget {
  final int index;
  final Map<String, dynamic> psnData;

  MarkDownResponseWidget({
    @required this.index,
    this.psnData,
  });

  String _stringifyMarkdown() {
    if (this.index == 0) {
      return _profileMarkDown();
    }

    if (this.index == 1) {
      return _trophyTitlesMarkDown();
    }

    if (this.index == 2) {
      return _trophySetMarkDown();
    }

    if (this.index == 4) {
      return _storeMarkDown();
    }

    return "";
  }

  String _profileMarkDown() {
    final d = this.psnData;

    final start = """
## Profile response JSON:
*. The response object from PSN(inside ['psn_data'] field) uses camelCase for it's field key.

    {
        "status": 200,
        "psn_data": {
            "onlineId": "${d['onlineId']}",
            "npId": "${d['npId']}",
            "region": "${d['region']}",
            "avatarUrl": "${d['avatarUrl']}",
            "aboutMe": "${d['aboutMe']}",
            "languagesUsed": [
""";

    var middle = "";
    final length = d['languagesUsed'].length;
    for (var i = 0; i < length; i++) {
      middle = middle +
          """
                "${d['languagesUsed'][i]}",     
""";
    }

    final end = """    
            ],
            "plus": ${d['plus']},
            "trophySummary": {
                "level": ${d['trophySummary']['level']},
                "progress": ${d['trophySummary']['progress']},
                "earnedTrophies":  {
                    "platinum": ${d['trophySummary']['earnedTrophies']['platinum']},
                    "gold": ${d['trophySummary']['earnedTrophies']['gold']},
                    "silver": ${d['trophySummary']['earnedTrophies']['silver']},
                    "bronze": ${d['trophySummary']['earnedTrophies']['bronze']}
                }
            }
        }
    }
""";

    final index = middle.lastIndexOf(',');
    return start + middle.replaceRange(index, index + 1, ' ') + end;
  }

  String _trophyTitlesMarkDown() {
    final d = this.psnData;
    final start = """
## Trophy titles response JSON:
*. The response object from PSN(inside ['psn_data'] field) uses camelCase for it's field key.
*. At most the first five of response trophyTitles are displayed.

    {
        "status": 200,
        "psn_data": {
            "totalResults": ${d['totalResults']},
            "offset": ${d['offset']},
            "trophyTitles": [
""";

    final end = """        
            ]
        }  
    }
""";

    var middle = "";

    var length = d['trophyTitles'].length;
    length = length > 5 ? 5 : length;

    for (var i = 0; i < length; i++) {
      middle = middle +
          """       
                {
                    "npCommunicationId": "${d['trophyTitles'][i]['npCommunicationId']}",
                    "trophyTitleName": "${d['trophyTitles'][i]['trophyTitleName']}",
                    "trophyTitleDetail": "${d['trophyTitles'][i]['trophyTitleDetail']}",
                    "trophyTitleIconUrl": "${d['trophyTitles'][i]['trophyTitleIconUrl']}",
                    "trophyTitlePlatfrom": "${d['trophyTitles'][i]['trophyTitlePlatfrom']}",
                    "hasTrophyGroups":  "${d['trophyTitles'][i]['hasTrophyGroups']}",
                    "definedTrophies": {
                        "platinum": ${d['trophyTitles'][i]['definedTrophies']['platinum']},
                        "gold": ${d['trophyTitles'][i]['definedTrophies']['gold']},
                        "silver": ${d['trophyTitles'][i]['definedTrophies']['silver']},
                        "bronze": ${d['trophyTitles'][i]['definedTrophies']['bronze']}
                    },
                    "titleDetail": {
                        "progress": ${d['trophyTitles'][i]['titleDetail']['progress']},
                        "earnedTrophies": {
                            "platinum": ${d['trophyTitles'][i]['titleDetail']['earnedTrophies']['platinum']},
                            "gold": ${d['trophyTitles'][i]['titleDetail']['earnedTrophies']['gold']},
                            "silver": ${d['trophyTitles'][i]['titleDetail']['earnedTrophies']['silver']},
                            "bronze": ${d['trophyTitles'][i]['titleDetail']['earnedTrophies']['bronze']}
                        },
                        "lastUpdateDate": "${d['trophyTitles'][i]['titleDetail']['lastUpdateDate']}"
                    }
                },   
""";
    }

    final index = middle.lastIndexOf(',');

    if (index != -1) {
      return start + middle.replaceRange(index, index + 1, ' ') + end;
    } else {
      return start + end;
    }
  }

  String _trophySetMarkDown() {
    final d = this.psnData;
    final start = """
## Trophy set response JSON:
*. The response object from PSN(inside ['psn_data'] field) uses camelCase for it's field key.
*. At most the first five of response trophies are displayed.

    {
        "status": 200,
        "psn_data": {
            "trophies": [
""";

    final end = """        
            ]
        }
    }       
""";

    var middle = "";
    var length = d['trophies'].length;
    length = length > 5 ? 5 : length;

    for (var i = 0; i < length; i++) {
      middle = middle +
          """       
                {
                    "trophyId": ${d['trophies'][i]['trophyId']},
                    "trophyHidden": ${d['trophies'][i]['trophyHidden']},
                    "trophyType": ${d['trophies'][i]['trophyType']},
                    "trophyName": ${d['trophies'][i]['trophyName']},
                    "trophyDetail": ${d['trophies'][i]['trophyDetail']},
                    "trophyIconUrl": ${d['trophies'][i]['trophyIconUrl']},
                    "trophyRare": ${d['trophies'][i]['trophyRare']},
                    "trophyEarnedRate": ${d['trophies'][i]['trophyEarnedRate']},
                    "userInfo": {
                        "onlineId": ${d['trophies'][i]['userInfo']['onlineId']},
                        "earned": ${d['trophies'][i]['userInfo']['earned']},
                        "earnedDate": ${d['trophies'][i]['userInfo']['earnedDate']},
                    }
                },
""";
    }

    final index = middle.lastIndexOf(',');
    if (index != -1) {
      return start + middle.replaceRange(index, index + 1, ' ') + end;
    } else {
      return start + end;
    }
  }

  String _storeMarkDown() {
    final d = this.psnData;

    JsonEncoder encoder = new JsonEncoder.withIndent('  ');
    String dd = encoder.convert(d);

    return """
## Store search response JSON:
*. Store response is pretty complex with lots of optional fields. Below is the raw response :

```javascript
    $dd
```
""";
  }

  @override
  Widget build(BuildContext context) {
    return MarkDownWidget(data: _stringifyMarkdown());
  }
}

class MarkDownWidget extends StatelessWidget {
  final String data;

  MarkDownWidget({this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 698,
          color: Colors.black12,
          padding: EdgeInsets.all(5),
          child: MarkdownBody(data: this.data, selectable: false),
        )
      ],
    );
  }
}
