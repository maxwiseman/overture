const association = {
	applinks: {
		details: [
			{
				appIDs: ["4B785Y2WUY.com.overture.news.swiftui"],
				components: [
					{
						"/": "/stories/*",
						comment: "Open published Overture stories in the iOS app.",
					},
				],
			},
		],
	},
};

export function GET() {
	return Response.json(association, {
		headers: {
			"Cache-Control": "public, max-age=3600",
		},
	});
}
