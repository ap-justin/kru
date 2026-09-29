#!/bin/bash
# a net/http service with a store interface
set -e
mkdir -p internal/store cmd/server
cat > go.mod <<'J'
module example.com/giving

go 1.24
J
cat > internal/store/store.go <<'J'
package store

import (
	"context"
	"database/sql"
)

type Campaign struct {
	ID      int64  `json:"id"`
	Name    string `json:"name"`
	GoalUSD int64  `json:"goal_usd"`
}

type Store struct{ DB *sql.DB }

// ListCampaigns returns every campaign, oldest first.
func (s *Store) ListCampaigns(ctx context.Context) ([]Campaign, error) {
	rows, err := s.DB.QueryContext(ctx, "SELECT id, name, goal_usd FROM campaigns ORDER BY id")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Campaign
	for rows.Next() {
		var c Campaign
		if err := rows.Scan(&c.ID, &c.Name, &c.GoalUSD); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}
J
cat > cmd/server/main.go <<'J'
package main

import (
	"log"
	"net/http"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusNoContent) })
	log.Fatal(http.ListenAndServe(":8080", mux))
}
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
