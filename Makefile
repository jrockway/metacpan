MINICPAN = /MINICPAN/authors/id/B/BD/BDFOY
INDEXER  = perl indexer.pl

run:
	find ${MINICPAN} -name "*.gz" | xargs ${INDEXER}