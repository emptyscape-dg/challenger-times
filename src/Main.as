[Setting name="Window position"]
vec2 windowPosition = vec2(0, 93);

[Setting name="Lock window position"]
bool lockPosition = false;

[Setting name="Snap to default position (locks window by default)"]
bool snapToDefault = false;

int pbTime = -1;
int challengerTime = -1;
string lastTickChallengeId = "";

// function adapted from banjee's editor helpers:
// https://github.com/skybaks/tm-editor-helpers, released under the Unlicense. original refs:
// https://github.com/BigBang1112/gbx-net/blob/master/Src/GBX.NET/Engines/Game/CGameCtnChallenge.md
// https://github.com/PyPlanet/PyPlanet/blob/master/pyplanet/utils/gbxparser.py
string ReadGbxXmlHeader(CGameCtnChallenge@ map)
{
	string xmlString = "";

	auto fidFile = cast<CSystemFidFile>(GetFidFromNod(map));
	if (fidFile !is null)
	{
		IO::File mapFile(fidFile.FullFileName);
		mapFile.Open(IO::FileMode::Read);

		uint64 xmlSize = 0;
		try
		{
			mapFile.SetPos(17);
			int headerChunkCount = mapFile.Read(4).ReadInt32();

			int sizeUntilXml = 0;
			bool isXmlChunkFound = false;

			for (int i = 0; i < headerChunkCount; i++)
			{
				uint chunkId = mapFile.Read(4).ReadInt32();
				if (chunkId == 50606085)
				{
					isXmlChunkFound = true;
				}
				uint chunkSize = mapFile.Read(4).ReadInt32() & 0x7FFFFFFF;
				if (!isXmlChunkFound)
				{
					sizeUntilXml += chunkSize;
				}
			}

			mapFile.SetPos(mapFile.Pos() + sizeUntilXml);

			xmlSize = mapFile.Read(4).ReadInt32();
			MemoryBuffer chunkBuffer = mapFile.Read(xmlSize);
			xmlString = chunkBuffer.ReadString(xmlSize);

			mapFile.Close();
		}
		catch
		{
			mapFile.Close();
			error("Error while reading GBX XML header. xmlSize was " + tostring(xmlSize));
		}
	}
	return xmlString;
}

int GetChallengerTime(string xml = "")
{
	try
	{
		XML::Document@ mapXmlDoc = XML::Document(xml);
		return Text::ParseInt(mapXmlDoc.Root().Child("header").Child("times").Attribute("challenger"));
	}
	catch
	{
		error("Error while parsing the XML header. xml was " + xml);
		return 0;
	}
}

void Render()
{
	CTrackMania@ app = cast<CTrackMania>(GetApp());
	if (snapToDefault)
	{
		windowPosition = vec2(0, 93);
		lockPosition = true;
	}
	int windowFlags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize | ((lockPosition || snapToDefault) ? UI::WindowFlags::NoMove : 0);

	CGameCtnChallenge@ map = app.RootMap;
	CGamePlayground@ playground = app.CurrentPlayground;
	CGameCtnEditor@ editor = app.Editor;
	CTrackManiaNetwork@ network = cast<CTrackManiaNetwork>(app.Network);
	string server = "";

	try
	{
		server = cast<CGameCtnNetServerInfo>(network.ServerInfo).ServerLogin;
	} catch {}

	if (map !is null && playground !is null && editor is null && server == "")
	{
		if (map.EdChallengeId != lastTickChallengeId)
		{
			challengerTime = GetChallengerTime(ReadGbxXmlHeader(map));
		}
		if (challengerTime > 0) {
			if (UI::Begin("Challenger Times", windowFlags))
			{
				UI::SetWindowPos(windowPosition, (lockPosition || snapToDefault) ? UI::Cond::Always : UI::Cond::Appearing);
				if (!lockPosition)
				{
    				windowPosition = vec2(UI::GetWindowPos());
				}

				UI::BeginTable("", 4, UI::TableFlags::SizingFixedFit);
				for (int i = 0; i < 4; i++) UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed);

				// headers
				UI::TableNextRow();
				UI::TableNextColumn();
				UI::TableNextColumn();
				UI::Text("");
				UI::TableNextColumn();
				UI::Text("Time");
				UI::TableNextColumn();
				UI::Text("Delta");

				// challenger time row
				UI::TableNextRow();
				UI::TableNextColumn();
				UI::Text("\\$0ba" + Icons::ClockO);
				UI::TableNextColumn();
				UI::Text("Challenger");
				UI::TableNextColumn();

				if (pbTime - challengerTime > 0 || pbTime == -1) UI::Text(Time::Format(challengerTime));
				else UI::Text("\\$0ba" + Time::Format(challengerTime));
				UI::TableNextColumn();

				CGameScoreAndLeaderBoardManagerScript@ scoreMgr = network.ClientManiaAppPlayground.ScoreMgr;
				CGameUserManagerScript@ userMgr = network.ClientManiaAppPlayground.UserMgr;
				pbTime = scoreMgr.Map_GetRecord_v2(userMgr.Users[0].Id, map.MapInfo.MapUid, "PersonalBest", "", "TimeAttack", "");

				if (pbTime != -1)
				{
					if (pbTime - challengerTime > 0)
					{
						UI::Text("\\$f77+" + Time::Format(pbTime - challengerTime));
					}
					else
					{
						UI::Text("\\$0ba" + Time::Format(pbTime - challengerTime));
					}
				}
				else
				{
					UI::Text("\\$777No record.");
				}

				UI::EndTable();
			}

			UI::End();
		}
		lastTickChallengeId = map.EdChallengeId;
	}
	else
	{
		lastTickChallengeId = "";
	}
}